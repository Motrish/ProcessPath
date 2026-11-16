#!/usr/bin/env python3
"""Build standalone OTOBO .opm from the ProcessPath .sopm source manifest."""
from pathlib import Path
import base64
import xml.etree.ElementTree as ET
from datetime import datetime, timezone

root = Path(__file__).resolve().parents[1]
manifest = ET.parse(root / 'ProcessPath.sopm')
package = manifest.getroot()
package.attrib['version'] = '1.0'
ET.SubElement(package, 'BuildDate').text = datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%M:%S')
ET.SubElement(package, 'BuildHost').text = 'local-build'
for file_el in package.findall('./Filelist/File'):
    file_path = root / file_el.attrib['Location']
    if not file_path.is_file():
        raise FileNotFoundError(file_path)
    file_el.attrib['Encode'] = 'Base64'
    file_el.text = base64.b64encode(file_path.read_bytes()).decode('ascii')
ET.indent(package, space='  ')
output = root.parent / 'ProcessPath-0.1.1.opm'
ET.ElementTree(package).write(output, encoding='utf-8', xml_declaration=True)
print(f'Created: {output} ({output.stat().st_size} bytes)')
