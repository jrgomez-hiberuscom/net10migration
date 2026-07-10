#!/usr/bin/env python3
from __future__ import annotations

import argparse
import re
from dataclasses import dataclass
from pathlib import Path
import xml.etree.ElementTree as ET

# Overrides explícitos de versión por paquete.
targetPackageVersions: dict[str, str] = {}
# Mapa opcional de paquetes reemplazados/renombrados (origen -> destino).
replacedPackages: dict[str, str] = {}


@dataclass(frozen=True)
class NuGetVersion:
    core: tuple[int, ...]
    prerelease: tuple[str | int, ...] | None


def parse_nuget_version(value: str) -> NuGetVersion:
    value = value.strip()
    core_text, _, prerelease_text = value.partition("-")

    core_parts: list[int] = []
    for part in core_text.split("."):
        try:
            core_parts.append(int(part))
        except ValueError:
            core_parts.append(0)

    prerelease: tuple[str | int, ...] | None = None
    if prerelease_text:
        tokens: list[str | int] = []
        for token in prerelease_text.split("."):
            if token.isdigit():
                tokens.append(int(token))
            else:
                tokens.append(token.lower())
        prerelease = tuple(tokens)

    return NuGetVersion(core=tuple(core_parts), prerelease=prerelease)


def compare_versions(left: str, right: str) -> int:
    a = parse_nuget_version(left)
    b = parse_nuget_version(right)

    size = max(len(a.core), len(b.core))
    for i in range(size):
        av = a.core[i] if i < len(a.core) else 0
        bv = b.core[i] if i < len(b.core) else 0
        if av != bv:
            return 1 if av > bv else -1

    if a.prerelease is None and b.prerelease is None:
        return 0
    if a.prerelease is None:
        return 1
    if b.prerelease is None:
        return -1

    size = max(len(a.prerelease), len(b.prerelease))
    for i in range(size):
        if i >= len(a.prerelease):
            return -1
        if i >= len(b.prerelease):
            return 1

        av = a.prerelease[i]
        bv = b.prerelease[i]
        if av == bv:
            continue

        if isinstance(av, int) and isinstance(bv, int):
            return 1 if av > bv else -1
        if isinstance(av, int):
            return -1
        if isinstance(bv, int):
            return 1
        return 1 if str(av) > str(bv) else -1

    return 0


def pick_max_version(current: str | None, candidate: str | None) -> str | None:
    if not candidate:
        return current
    if current is None:
        return candidate
    return candidate if compare_versions(candidate, current) > 0 else current


def update_max_version(versions: dict[str, str], package_id: str, version: str | None) -> None:
    if not version:
        return
    versions[package_id] = pick_max_version(versions.get(package_id), version) or version


def ns_tag(tag: str, namespace: str | None) -> str:
    return f"{{{namespace}}}{tag}" if namespace else tag


def detect_namespace(root: ET.Element) -> str | None:
    match = re.match(r"\{(.+)}", root.tag)
    return match.group(1) if match else None


def extract_package_id(package_reference: ET.Element) -> str | None:
    return package_reference.get("Include") or package_reference.get("Update")


def get_package_reference_version(
    package_reference: ET.Element, namespace: str | None
) -> str | None:
    version = package_reference.get("Version")
    if version:
        return version.strip()

    version_node = package_reference.find(ns_tag("Version", namespace))
    if version_node is not None and version_node.text:
        return version_node.text.strip()

    return None


def remove_package_reference_version(
    package_reference: ET.Element, namespace: str | None
) -> bool:
    changed = False

    if "Version" in package_reference.attrib:
        del package_reference.attrib["Version"]
        changed = True

    version_node = package_reference.find(ns_tag("Version", namespace))
    if version_node is not None:
        package_reference.remove(version_node)
        if len(package_reference) == 0 and (package_reference.text or "").strip() == "":
            package_reference.text = None
        changed = True

    return changed


def collect_existing_package_versions(
    props_root: ET.Element, namespace: str | None
) -> dict[str, str]:
    versions: dict[str, str] = {}
    for package_version in props_root.findall(f".//{ns_tag('PackageVersion', namespace)}"):
        package_id = package_version.get("Include") or package_version.get("Update")
        version = package_version.get("Version")
        if package_id and version:
            versions[package_id] = version
    return versions


def apply_package_versions_to_props(
    props_root: ET.Element,
    namespace: str | None,
    effective_versions: dict[str, str],
) -> bool:
    changed = False
    package_versions = props_root.findall(f".//{ns_tag('PackageVersion', namespace)}")
    by_id: dict[str, ET.Element] = {}

    for package_version in package_versions:
        package_id = package_version.get("Include") or package_version.get("Update")
        if package_id:
            by_id[package_id] = package_version

    for package_id, version in sorted(effective_versions.items(), key=lambda x: x[0].lower()):
        node = by_id.get(package_id)
        if node is None:
            item_group = props_root.find(ns_tag("ItemGroup", namespace))
            if item_group is None:
                item_group = ET.SubElement(props_root, ns_tag("ItemGroup", namespace))
            node = ET.SubElement(item_group, ns_tag("PackageVersion", namespace))
            node.set("Include", package_id)
            node.set("Version", version)
            changed = True
            continue

        if node.get("Version") != version:
            node.set("Version", version)
            changed = True

    return changed


def process_directory_packages_props(props_path: Path) -> tuple[int, int]:
    props_tree = ET.parse(props_path)
    props_root = props_tree.getroot()
    namespace = detect_namespace(props_root)

    existing_versions = collect_existing_package_versions(props_root, namespace)

    discovered_versions: dict[str, str] = {}
    changed_projects = 0

    for csproj_path in props_path.parent.rglob("*.csproj"):
        tree = ET.parse(csproj_path)
        root = tree.getroot()
        csproj_namespace = detect_namespace(root)
        project_changed = False

        for package_reference in root.findall(f".//{ns_tag('PackageReference', csproj_namespace)}"):
            package_id = extract_package_id(package_reference)
            if not package_id:
                continue

            version = get_package_reference_version(package_reference, csproj_namespace)
            update_max_version(discovered_versions, package_id, version)
            replaced_package = replacedPackages.get(package_id)
            if replaced_package:
                update_max_version(discovered_versions, replaced_package, version)

            if remove_package_reference_version(package_reference, csproj_namespace):
                project_changed = True

        if project_changed:
            ET.indent(tree, space="  ")
            tree.write(csproj_path, encoding="utf-8", xml_declaration=True)
            changed_projects += 1

    effective_versions = dict(existing_versions)
    for package_id, version in discovered_versions.items():
        effective_versions[package_id] = version

    for package_id, version in targetPackageVersions.items():
        if version:
            effective_versions[package_id] = version

    props_changed = apply_package_versions_to_props(props_root, namespace, effective_versions)
    if props_changed:
        ET.indent(props_tree, space="  ")
        props_tree.write(props_path, encoding="utf-8", xml_declaration=True)

    return changed_projects, 1 if props_changed else 0


def main() -> int:
    parser = argparse.ArgumentParser(
        description=(
            "Centraliza versiones de PackageReference en Directory.Packages.props "
            "eliminando versiones de los csproj."
        )
    )
    parser.add_argument(
        "root",
        nargs="?",
        default=".",
        help="Directorio raíz donde buscar Directory.Packages.props",
    )
    args = parser.parse_args()

    root_path = Path(args.root).resolve()
    props_files = sorted(root_path.rglob("Directory.Packages.props"))
    if not props_files:
        print("No se ha encontrado ningún Directory.Packages.props")
        return 1

    total_projects = 0
    total_props = 0

    for props_path in props_files:
        changed_projects, changed_props = process_directory_packages_props(props_path)
        total_projects += changed_projects
        total_props += changed_props

    print(
        f"Procesados {len(props_files)} Directory.Packages.props, "
        f"csproj modificados: {total_projects}, props modificados: {total_props}."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
