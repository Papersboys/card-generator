#!/usr/bin/env python3
"""Protocol-only stdio smoke test; never sends a valid tool call to a running App."""
import json,subprocess,sys
binary=sys.argv[1]
requests=[
 {'jsonrpc':'2.0','id':1,'method':'initialize','params':{'protocolVersion':'2025-11-25','capabilities':{},'clientInfo':{'name':'offline-test','version':'1'}}},
 {'jsonrpc':'2.0','method':'notifications/initialized'},
 {'jsonrpc':'2.0','id':2,'method':'tools/list'},
 {'jsonrpc':'2.0','id':3,'method':'ping'},
 {'jsonrpc':'2.0','id':4,'method':'tools/call','params':{'name':'link_card_create_request','arguments':{'account_id':'link','confirmed':False}}},
 {'jsonrpc':'2.0','id':5,'method':'tools/call','params':{'name':'link_card_accounts','arguments':'invalid'}},
 {'jsonrpc':'2.0','id':6,'method':'unknown'},
 {'jsonrpc':'2.0','id':{'invalid':True},'method':'ping'},
]
wire='\n'.join(json.dumps(r) for r in requests)+'\nnot-json\n'
result=subprocess.run([binary],input=wire,text=True,capture_output=True,check=True,timeout=15)
rows=[json.loads(line) for line in result.stdout.splitlines()]
assert len(rows)==8 and not result.stderr
assert rows[0]['result']['protocolVersion']=='2025-11-25'
tools=rows[1]['result']['tools'];assert len(tools)==7
assert all(t['inputSchema']['additionalProperties'] is False for t in tools)
assert next(t for t in tools if t['name']=='link_card_cancel_request')['annotations']['destructiveHint'] is True
assert rows[2]['result']=={}
assert rows[3]['result']['isError'] and rows[4]['result']['isError']
assert rows[5]['error']['code']==-32601
assert rows[6]['error']['code']==-32600 and rows[7]['error']['code']==-32700
root=__import__('pathlib').Path(__file__).resolve().parent.parent
catalog=json.loads((root/'docs/ai-catalog.json').read_text())
assert catalog['specVersion']=='1.0' and len(catalog['entries'])==2
assert len({e['identifier'] for e in catalog['entries']})==2
for entry in catalog['entries']:
    assert ('url' in entry)^('data' in entry)
    assert entry['url'].startswith('https://papersboys.github.io/card-generator/')
    relative=entry['url'].split('/card-generator/',1)[1]
    assert (root/'docs'/relative).is_file()
assert (root/'Agent/skills/link-card/SKILL.md').read_bytes()==(root/'docs/agent/skills/link-card/SKILL.md').read_bytes()
print('PASS: stdio initialize/tools/ping/errors/notifications, annotations, no valid live calls, and static catalog artifact consistency')
