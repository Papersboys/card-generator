#!/usr/bin/env python3
"""Publish static, credential-free discovery metadata for manual local MCP setup."""
import json
import plistlib
import shutil
from pathlib import Path
root=Path(__file__).resolve().parent.parent
version=plistlib.loads((root/'Info.plist').read_bytes())['CFBundleShortVersionString']
public=root/'docs'/'agent'
(public/'skills'/'link-card').mkdir(parents=True,exist_ok=True)
shutil.copyfile(root/'Agent'/'skills'/'link-card'/'SKILL.md',public/'skills'/'link-card'/'SKILL.md')
shutil.copyfile(root/'Agent'/'mcp-config.json',public/'mcp-config.json')
base='https://papersboys.github.io/card-generator/agent'
catalog={
    'specVersion':'1.0',
    'host':{'displayName':'Link Card','documentationUrl':'https://papersboys.github.io/card-generator/guide.en.html#ai-mcp'},
    'entries':[
        {'identifier':base+'/skills/link-card','displayName':'Link Card Skill','type':'application/agent-skills+md','version':version,'url':base+'/skills/link-card/SKILL.md','description':'User-reviewed Link wallet spend requests through local MCP; no PAN/CVC access.','tags':['payments','macos','skill']},
        {'identifier':base+'/mcp','displayName':'Link Card local MCP configuration','type':'application/vnd.link-card.mcp-config+json','version':version,'url':base+'/mcp-config.json','description':'Manual stdio connection configuration. Requires an installed, signed-in running App with Local MCP enabled. This is a vendor-specific config, not an A2A or standardized MCP Server Card.','tags':['mcp','stdio','macos']}
    ]
}
for name in ['ai-catalog.json']:
    (root/'docs'/name).write_text(json.dumps(catalog,indent=2,ensure_ascii=False)+'\n')
(root/'docs'/'.nojekyll').touch()
print('Built static AI catalog, skill and MCP configuration')
