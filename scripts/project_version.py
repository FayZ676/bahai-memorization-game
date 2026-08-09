#!/usr/bin/env python3
import argparse
import pathlib
import re
import sys

PBXPROJ = pathlib.Path(__file__).resolve().parent.parent / "MemorizationGame.xcodeproj" / "project.pbxproj"
APP_BUNDLE_ID = "com.faizififita.MemorizationGame"

BLOCK = re.compile(
    r"(?P<head>\t\t[0-9A-F]+ /\* \w+ \*/ = \{\n\t\t\tisa = XCBuildConfiguration;\n\t\t\tbuildSettings = \{\n)"
    r"(?P<settings>.*?)"
    r"(?P<tail>\n\t\t\t\};\n\t\t\tname = \w+;\n\t\t\};)",
    re.S,
)


def app_blocks(text):
    for match in BLOCK.finditer(text):
        settings = match.group("settings")
        if f"PRODUCT_BUNDLE_IDENTIFIER = {APP_BUNDLE_ID};" in settings:
            yield match


def read_setting(text, key):
    values = set()
    for match in app_blocks(text):
        found = re.search(rf"^\t+{key} = (.+);$", match.group("settings"), re.M)
        if found:
            values.add(found.group(1))
    if len(values) != 1:
        sys.exit(f"expected one {key} across app build configurations, found {sorted(values) or 'none'}")
    return values.pop()


def write_setting(text, key, value):
    def replace_block(match):
        settings = re.sub(rf"^(\t+){key} = .+;$", rf"\g<1>{key} = {value};", match.group("settings"), flags=re.M)
        return match.group("head") + settings + match.group("tail")

    updated = []
    result = []
    cursor = 0
    for match in app_blocks(text):
        result.append(text[cursor:match.start()])
        result.append(replace_block(match))
        cursor = match.end()
        updated.append(match)
    result.append(text[cursor:])
    if not updated:
        sys.exit("no app build configurations found in project.pbxproj")
    return "".join(result)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--get", choices=["marketing", "build"])
    parser.add_argument("--set-marketing")
    parser.add_argument("--set-build")
    args = parser.parse_args()

    text = PBXPROJ.read_text()

    if args.get == "marketing":
        print(read_setting(text, "MARKETING_VERSION"))
        return
    if args.get == "build":
        print(read_setting(text, "CURRENT_PROJECT_VERSION"))
        return

    if args.set_marketing:
        text = write_setting(text, "MARKETING_VERSION", args.set_marketing)
    if args.set_build:
        text = write_setting(text, "CURRENT_PROJECT_VERSION", args.set_build)
    PBXPROJ.write_text(text)


if __name__ == "__main__":
    main()
