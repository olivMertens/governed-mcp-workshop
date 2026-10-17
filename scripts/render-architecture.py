"""Render the deliberately small, validated mxGraph subset used by this workshop."""

import argparse
import copy
import hashlib
import re
import shutil
import struct
import textwrap
import urllib.parse
import xml.etree.ElementTree as ET
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SVG = "http://www.w3.org/2000/svg"
ET.register_namespace("", SVG)
SUPPORTED = {
    "shape", "rounded", "fillColor", "strokeColor", "strokeWidth", "dashed",
    "fontColor", "fontSize", "fontStyle", "align", "verticalAlign", "whiteSpace",
    "spacingLeft", "image", "aspect", "container", "html", "edgeStyle",
    "endArrow", "endFill", "exitX", "exitY", "entryX", "entryY",
}


def svg_node(parent, name, attributes=None, text=None):
    node = ET.SubElement(parent, f"{{{SVG}}}{name}", {k: str(v) for k, v in (attributes or {}).items()})
    node.text = text
    return node


def style(cell):
    pairs = [part.split("=", 1) for part in cell.get("style", "").split(";") if part]
    if any(len(pair) != 2 for pair in pairs):
        raise ValueError(f"Unsupported named mxGraph style: {cell.get('id')}")
    result = dict(pairs)
    if set(result) - SUPPORTED:
        raise ValueError(f"Unsupported styles on {cell.get('id')}: {set(result) - SUPPORTED}")
    if result.get("rounded", "0") != "0" or result.get("html", "0") != "0":
        raise ValueError("Only square-cornered components and plain text are supported.")
    for key, allowed in {
        "shape": {"rectangle", "text", "image"}, "align": {"left"}, "verticalAlign": {"middle"},
        "whiteSpace": {"wrap"}, "edgeStyle": {"orthogonalEdgeStyle"}, "aspect": {"fixed"},
        "fontStyle": {"0", "1"}, "container": {"0", "1"}, "dashed": {"0", "1"},
    }.items():
        if key in result and result[key] not in allowed:
            raise ValueError(f"Unsupported {key} value on {cell.get('id')}: {result[key]}")
    return result


def number(element, name, default=0):
    return float(element.get(name, default))


def bounds(cell, cells):
    geometry = cell.find("mxGeometry")
    if geometry is None or geometry.get("relative", "0") != "0":
        raise ValueError(f"Vertex needs absolute geometry: {cell.get('id')}")
    x, y = number(geometry, "x"), number(geometry, "y")
    parent = cells.get(cell.get("parent"))
    if parent is not None and parent.get("vertex") == "1":
        px, py, _, _ = bounds(parent, cells)
        x, y = x + px, y + py
    return x, y, number(geometry, "width"), number(geometry, "height")


def segments(points):
    return list(zip(points, points[1:]))


def intersects_box(segment, box):
    (x1, y1), (x2, y2) = segment
    x, y, width, height = box
    if y1 == y2:
        return y < y1 < y + height and max(min(x1, x2), x) < min(max(x1, x2), x + width)
    return x < x1 < x + width and max(min(y1, y2), y) < min(max(y1, y2), y + height)


def edge_points(cell, cells, styles):
    source, target = cells[cell.get("source")], cells[cell.get("target")]
    sx, sy, sw, sh = bounds(source, cells)
    tx, ty, tw, th = bounds(target, cells)
    s = styles[cell.get("id")]
    for key in ("exitX", "exitY", "entryX", "entryY"):
        if key not in s:
            raise ValueError(f"Explicit anchors required: {cell.get('id')}")
    start = (sx + sw * float(s["exitX"]), sy + sh * float(s["exitY"]))
    end = (tx + tw * float(s["entryX"]), ty + th * float(s["entryY"]))
    waypoints = cell.findall("./mxGeometry/Array[@as='points']/mxPoint")
    points = [start] + [(number(p, "x"), number(p, "y")) for p in waypoints] + [end]
    if any(a == b or (a[0] != b[0] and a[1] != b[1]) for a, b in segments(points)):
        raise ValueError(f"Source routing must contain nonzero orthogonal segments: {cell.get('id')}")
    before, final = points[-2:]
    if abs(final[0] - before[0]) + abs(final[1] - before[1]) < 15:
        raise ValueError("Final arrow approach is too short.")
    if not ((float(s["entryX"]) in (0, 1) and before[1] == final[1]) or
            (float(s["entryY"]) in (0, 1) and before[0] == final[0])):
        raise ValueError("Arrow must approach a target border perpendicularly.")
    return points


def check_geometry(vertices, edges, cells, styles):
    for edge, points in edges:
        excluded = {edge.get("source"), edge.get("target")}
        for vertex in vertices:
            if vertex.get("id") in excluded or styles[vertex.get("id")].get("container") == "1":
                continue
            if vertex.get("parent") in excluded:
                continue
            if any(intersects_box(segment, bounds(vertex, cells)) for segment in segments(points)):
                raise ValueError(f"Edge {edge.get('id')} crosses {vertex.get('id')}")
    all_segments = [(edge.get("id"), segment) for edge, points in edges for segment in segments(points)]
    for index, (first_id, (a, b)) in enumerate(all_segments):
        for second_id, (c, d) in all_segments[index + 1:]:
            if first_id == second_id:
                continue
            horizontal = a[1] == b[1]
            if horizontal == (c[1] == d[1]):
                axis, lane = (0, 1) if horizontal else (1, 0)
                if max(min(a[axis], b[axis]), min(c[axis], d[axis])) < min(max(a[axis], b[axis]), max(c[axis], d[axis])):
                    if abs(a[lane] - c[lane]) < 16:
                        raise ValueError(f"Parallel edge overlap/clearance: {first_id}, {second_id}")
            else:
                h1, h2, v1, v2 = (a, b, c, d) if horizontal else (c, d, a, b)
                if min(h1[0], h2[0]) <= v1[0] <= max(h1[0], h2[0]) and min(v1[1], v2[1]) <= h1[1] <= max(v1[1], v2[1]):
                    raise ValueError(f"Perpendicular edge intersection: {first_id}, {second_id}")


def embed_icon(parent, source, prefix, box):
    if not source.startswith("data:image/svg+xml,"):
        raise ValueError("Icons must be embedded SVG, not remote or filesystem URLs.")
    icon = ET.fromstring(urllib.parse.unquote(source.split(",", 1)[1]))
    if icon.tag != f"{{{SVG}}}svg" or "viewBox" not in icon.attrib:
        raise ValueError("Icon must have an SVG root and viewBox.")
    for node in icon.iter():
        if node.tag.rsplit("}", 1)[-1] in ("script", "foreignObject", "style"):
            raise ValueError("Active or stylesheet content is forbidden in icons.")
        for attribute, value in node.attrib.items():
            if attribute.lower().startswith("on"):
                raise ValueError("Event handlers are forbidden.")
            if attribute.rsplit("}", 1)[-1] == "href" and not value.startswith("#"):
                raise ValueError("External icon references are forbidden.")
            if "url(" in value and not re.fullmatch(r"url\(#[A-Za-z0-9_.:-]+\)", value):
                raise ValueError("External CSS assets are forbidden.")
    identifiers = {node.get("id"): prefix + node.get("id") for node in icon.iter() if node.get("id")}
    for node in icon.iter():
        for attribute, value in list(node.attrib.items()):
            if attribute == "id":
                node.set(attribute, identifiers[value])
            else:
                for old, new in identifiers.items():
                    value = value.replace(f"url(#{old})", f"url(#{new})")
                    if value == f"#{old}":
                        value = f"#{new}"
                node.set(attribute, value)
    x, y, width, height = box
    icon.attrib.update(x=str(x), y=str(y), width=str(width), height=str(height), preserveAspectRatio="xMidYMid meet")
    parent.append(copy.deepcopy(icon))


def add_text(parent, value, box, s):
    x, y, width, height = box
    size = float(s.get("fontSize", 16))
    left = float(s.get("spacingLeft", 16))
    line_width = max(1, int((width - left - 14) / (size * 0.58)))
    lines = [line for paragraph in value.split("\n") for line in (textwrap.wrap(paragraph, line_width, break_long_words=False) or [""])]
    line_height = size * 1.35
    if len(lines) * line_height > height - 8:
        raise ValueError(f"Text does not fit its source box: {value}")
    baseline = y + (height - len(lines) * line_height) / 2 + size
    text = svg_node(parent, "text", {"x": x + left, "y": baseline, "font-size": size,
        "font-family": "Segoe UI, Arial, sans-serif", "fill": s.get("fontColor", "#172c48"),
        "font-weight": "600" if s.get("fontStyle") == "1" else "400"})
    for index, line in enumerate(lines):
        svg_node(text, "tspan", {"x": x + left, "dy": 0 if index == 0 else line_height}, line)


def render(page, output, check=False):
    graph = page.find("mxGraphModel")
    if graph is None:
        raise ValueError("Use uncompressed drawio XML.")
    width, height = int(graph.get("pageWidth")), int(graph.get("pageHeight"))
    cells = {cell.get("id"): cell for cell in graph.findall("./root/mxCell")}
    styles = {identifier: style(cell) for identifier, cell in cells.items()}
    vertices = [cell for cell in cells.values() if cell.get("vertex") == "1"]
    edges = [(cell, edge_points(cell, cells, styles)) for cell in cells.values() if cell.get("edge") == "1"]
    check_geometry(vertices, edges, cells, styles)
    root = ET.Element(f"{{{SVG}}}svg", {"viewBox": f"0 0 {width} {height}", "width": str(width),
        "height": str(height), "role": "img", "aria-labelledby": "diagram-title diagram-description"})
    svg_node(root, "title", {"id": "diagram-title"}, page.get("name"))
    svg_node(root, "desc", {"id": "diagram-description"}, page.get("description"))
    svg_node(root, "rect", {"width": width, "height": height, "fill": "#ffffff"})
    defs = svg_node(root, "defs")
    for color, suffix in (("#1659dc", "blue"), ("#14704b", "green")):
        marker = svg_node(defs, "marker", {"id": f"arrow-{suffix}", "viewBox": "0 0 10 10",
            "refX": 10, "refY": 5, "markerWidth": 8, "markerHeight": 8, "orient": "auto"})
        svg_node(marker, "path", {"d": "M 0 0 L 10 5 L 0 10 Z", "fill": color})
    groups = {}

    def render_vertex(vertex):
        identifier = vertex.get("id")
        if identifier in groups:
            return groups[identifier]
        s = styles[identifier]
        x, y, w, h = bounds(vertex, cells)
        parent = cells.get(vertex.get("parent"))
        if parent is not None and parent.get("vertex") == "1":
            owner = render_vertex(parent)
            px, py, _, _ = bounds(parent, cells)
            x, y = x - px, y - py
        else:
            owner = root
        group = svg_node(owner, "g", {"id": identifier, "transform": f"translate({x:g} {y:g})"})
        groups[identifier] = group
        if s.get("shape") == "image":
            embed_icon(group, s.get("image", ""), identifier + "-", (0, 0, w, h))
        else:
            if s.get("shape", "rectangle") != "text":
                attributes = {"width": w, "height": h, "rx": 0, "fill": s.get("fillColor", "#eaf0ff"),
                    "stroke": s.get("strokeColor", "#1659dc"), "stroke-width": s.get("strokeWidth", 1)}
                if s.get("dashed") == "1":
                    attributes["stroke-dasharray"] = "8 6"
                svg_node(group, "rect", attributes)
            if vertex.get("value"):
                add_text(group, vertex.get("value"), (0, 0, w, h), s)
        return group

    for vertex in vertices:
        render_vertex(vertex)
    for edge, points in edges:
        s = styles[edge.get("id")]
        if s.get("endArrow") != "block" or s.get("endFill") != "1":
            raise ValueError("Only filled block arrowheads are supported.")
        color = s.get("strokeColor", "#1659dc")
        if color not in ("#1659dc", "#14704b"):
            raise ValueError("Unsupported edge color.")
        path = svg_node(root, "path", {"d": "M " + " L ".join(f"{x:g} {y:g}" for x, y in points),
            "fill": "none", "stroke": color, "stroke-width": 2,
            "marker-end": f"url(#arrow-{'green' if color == '#14704b' else 'blue'})"})
        if s.get("dashed") == "1":
            path.set("stroke-dasharray", "6 5")
        if edge.get("value"):
            if len(points) != 2 or points[0][1] != points[1][1]:
                raise ValueError("Place routed-edge labels in explicit source text cells.")
            x, y = points[0]
            label_box = (x + 28, y - 58, points[1][0] - x - 56, 50)
            add_text(root, edge.get("value"), label_box, {"fontSize": "12", "spacingLeft": "0"})
    data = ET.tostring(root, encoding="utf-8", xml_declaration=True) + b"\n"
    if check:
        if output.read_bytes() != data:
            raise ValueError(f"Stale SVG export: {output.name}")
    else:
        output.write_bytes(data)
    return width, height


def check_png(path, svg, size):
    data = path.read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n" or struct.unpack(">II", data[16:24]) != size:
        raise ValueError(f"Invalid PNG dimensions/signature: {path.name}")
    position, provenance = 8, None
    while position < len(data):
        length = struct.unpack(">I", data[position:position + 4])[0]
        chunk = data[position + 4:position + 8 + length]
        crc = struct.unpack(">I", data[position + 8 + length:position + 12 + length])[0]
        if zlib.crc32(chunk) != crc:
            raise ValueError(f"Invalid PNG chunk: {path.name}")
        if chunk.startswith(b"tEXtworkshop-svg-sha256\0"):
            provenance = chunk.split(b"\0", 1)[1].decode("ascii")
        position += length + 12
    if position != len(data) or provenance != hashlib.sha256(svg.read_bytes()).hexdigest():
        raise ValueError(f"Stale PNG export: {path.name}. Regenerate SVG and PNG together.")


def stamp_png(path, svg):
    data = path.read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError(f"PNG rendering failed: {path.name}")
    payload = b"tEXtworkshop-svg-sha256\0" + hashlib.sha256(svg.read_bytes()).hexdigest().encode("ascii")
    chunk = struct.pack(">I", len(payload) - 4) + payload + struct.pack(">I", zlib.crc32(payload))
    path.write_bytes(data[:33] + chunk + data[33:])


def mermaid_label(value):
    return (value.replace("#", "#35;").replace("&", "#38;").replace('"', "#quot;")
            .replace("<", "#60;").replace(">", "#62;").replace("\n", " / "))


def mermaid(page):
    cells = {cell.get("id"): cell for cell in page.findall("./mxGraphModel/root/mxCell")}
    styles = {identifier: style(cell) for identifier, cell in cells.items()}
    components = [cell for cell in cells.values() if cell.get("vertex") == "1"
                  and styles[cell.get("id")].get("shape", "rectangle") == "rectangle"
                  and styles[cell.get("id")].get("container") != "1"]
    boundaries = [cell for cell in cells.values() if styles[cell.get("id")].get("container") == "1"]
    identifiers = {cell.get("id"): "n_" + re.sub(r"[^a-zA-Z0-9_]", "_", cell.get("id")) for cell in components}
    if len(set(identifiers.values())) != len(components):
        raise ValueError("Mermaid component identifiers collide.")
    groups = {boundary.get("id"): [] for boundary in boundaries}
    outside = []
    for cell in components:
        x, y, w, h = bounds(cell, cells)
        owners = []
        for boundary in boundaries:
            bx, by, bw, bh = bounds(boundary, cells)
            if bx <= x and by <= y and x + w <= bx + bw and y + h <= by + bh:
                owners.append(boundary.get("id"))
        if len(owners) > 1:
            raise ValueError("Nested/overlapping Mermaid ownership needs an explicit reviewed representation.")
        (groups[owners[0]] if owners else outside).append(cell)

    lines = ["flowchart LR"]
    for cell in cells.values():
        if cell.get("id", "").startswith("lane-label-"):
            lines.append("  %% " + cell.get("value").replace("\n", " / "))

    def declare(cell, indent):
        if not cell.get("value"):
            raise ValueError("Every Mermaid component needs a label.")
        lines.append(f'{indent}{identifiers[cell.get("id")]}["{mermaid_label(cell.get("value"))}"]')

    for cell in outside:
        declare(cell, "  ")
    for index, boundary in enumerate(boundaries):
        caption = cells["boundary-label-" + boundary.get("id").removeprefix("boundary-")].get("value")
        lines.append(f'  subgraph boundary_{index}["{mermaid_label(caption)}"]')
        for cell in groups[boundary.get("id")]:
            declare(cell, "    ")
        lines.append("  end")
        color = styles[boundary.get("id")]["strokeColor"]
        lines.append(f"  style boundary_{index} fill:#ffffff,stroke:{color},stroke-dasharray:8 6")
    for cell in cells.values():
        if cell.get("edge") != "1":
            continue
        source, target = cell.get("source"), cell.get("target")
        if source not in identifiers or target not in identifiers:
            raise ValueError("Mermaid must preserve every edge between real components.")
        arrow = "-.->" if styles[cell.get("id")].get("dashed") == "1" else "-->"
        label = f'|"{mermaid_label(cell.get("value"))}"|' if cell.get("value") else ""
        lines.append(f"  {identifiers[source]} {arrow}{label} {identifiers[target]}")
    for cell in components:
        s = styles[cell.get("id")]
        lines.append(f'  style {identifiers[cell.get("id")]} fill:{s["fillColor"]},stroke:{s["strokeColor"]},color:{s["fontColor"]}')
    return "\n".join(lines)


def architecture_documents(pages, directory, check):
    for language in ("en", "fr"):
        french = language == "fr"
        name = "STEPS.fr.md" if french else "STEPS.md"
        lines = [
            "# " + ("L'architecture, étape par étape" if french else "Architecture, step by step"), "",
            ("Ces schémas montrent ce que le parcours vous fait construire, pas des ressources déjà déployées. "
             "Les preuves de validation figurent dans le suivi d'avancement." if french else
             "These diagrams show learning targets, not deployed resources. See build progress for validation evidence."), "",
            ("Le Model Context Protocol (MCP) relie un client à des outils. "
             "Chaque étape ajoute un contrôle ou précise qui est responsable de quoi." if french else
             "The Model Context Protocol (MCP) connects a client to tools. "
             "Each step adds a control or explains an ownership boundary."), "",
            ("[Ce qui est réellement disponible](../../docs/fr/IMPLEMENTATION-STATUS.md). "
             "[Modifier les schémas et vérifier les icônes](README.fr.md)." if french else
             "[What is actually available](../../docs/IMPLEMENTATION-STATUS.md). "
             "[Edit diagrams and verify icon provenance](README.md)."), "",
            ("Ce fichier est généré à partir de `workshop.drawio` : ne le modifiez pas directement. "
             "Chaque cadre délimite un périmètre de responsabilité ; une vue répétée désigne le même environnement. "
             "GitHub affiche le schéma Mermaid ; l'application affiche le SVG équivalent, avec ses icônes et son tracé vérifiés."
             if french else
             "Generated from `workshop.drawio`; do not edit separately. Frames are ownership boundaries; "
             "repeated views refer to the same environment. GitHub renders Mermaid; "
             "the application displays the equivalent SVG with verified icons and routing."), "",
        ]
        for page in pages:
            if not page.get("id").endswith("." + language):
                continue
            identifier = page.get("id")
            lines.extend([
                "## " + page.get("name"), "", page.get("description"), "",
                f"[SVG]({identifier}.svg) · [PNG]({identifier}.png)", "",
                "```mermaid", mermaid(page), "```", "",
            ])
        lines.extend([
            "## Sources", "",
            "- [Draw.io](workshop.drawio).",
            "- [GitHub Mermaid](https://docs.github.com/en/get-started/writing-on-github/working-with-advanced-formatting/creating-diagrams).",
            "- [Mermaid flowcharts](https://mermaid.js.org/syntax/flowchart.html).", "",
            ("Dernière vérification : 2026-10-14." if french else "Last verified: 2026-10-14."), "",
        ])
        data = "\n".join(lines)
        output = directory / name
        if check:
            if output.read_text(encoding="utf-8") != data:
                raise ValueError(f"Stale Mermaid documentation: {name}")
        else:
            output.write_text(data, encoding="utf-8", newline="\n")
        print(f"PASS {name}: nine Mermaid graphs from the same Draw.io source")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--svg-only", action="store_true", help="Regenerate SVG only; PNG exports then need regeneration before publication.")
    mode.add_argument("--check", action="store_true", help="Verify source, SVG freshness and PNG provenance without changing exports or starting a browser.")
    parser.add_argument("--browser", help="Existing Chromium/Edge executable for local, offline PNG rendering.")
    args = parser.parse_args()
    browser = args.browser or shutil.which("msedge") or shutil.which("chromium") or shutil.which("google-chrome")
    if not args.svg_only and not args.check and (not browser or not Path(browser).is_file()):
        parser.error("PNG export requires an existing Chromium/Edge --browser path; no tool is installed automatically.")
    automation = browser_process = None
    source = ROOT / "assets" / "architecture" / "workshop.drawio"
    document = ET.parse(source)
    pages = document.findall("diagram")
    expected = {f"{module}.{language}" for module in ("00", "01", "02", "03", "04", "05", "06", "07", "99") for language in ("en", "fr")}
    if {page.get("id") for page in pages} != expected or len(pages) != len(expected):
        raise ValueError("Exactly one English and French page per module is required.")
    try:
        if not args.svg_only and not args.check:
            from playwright.sync_api import sync_playwright

            automation = sync_playwright().start()
            browser_process = automation.chromium.launch(executable_path=str(browser), headless=True)
        for page in pages:
            output = source.with_name(page.get("id") + ".svg")
            width, height = render(page, output, args.check)
            if args.check:
                check_png(output.with_suffix(".png"), output, (width, height))
            elif not args.svg_only:
                png = output.with_suffix(".png")
                png.unlink(missing_ok=True)
                tab = browser_process.new_page(viewport={"width": width, "height": height}, device_scale_factor=1)
                try:
                    tab.route("http://**/*", lambda route: route.abort())
                    tab.route("https://**/*", lambda route: route.abort())
                    tab.goto(output.as_uri())
                    tab.screenshot(path=str(png))
                finally:
                    tab.close()
                stamp_png(png, output)
                check_png(png, output, (width, height))
            print(f"PASS {page.get('id')}: XML, routing, text fit, embedded SVG" + (", PNG" if not args.svg_only else ""))
        architecture_documents(pages, source.parent, args.check)
    finally:
        if browser_process:
            browser_process.close()
        if automation:
            automation.stop()


if __name__ == "__main__":
    main()
