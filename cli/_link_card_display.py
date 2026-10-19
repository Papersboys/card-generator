#!/usr/bin/env python3
import json,shutil,sys,textwrap,os

def objects(x):
    if isinstance(x,dict):
        yield x
        for v in x.values():yield from objects(v)
    elif isinstance(x,list):
        for v in x:yield from objects(v)

def pick(data,*keys):
    for obj in objects(data):
        for key in keys:
            if obj.get(key) is not None and obj[key]!='':return obj[key]
    return None

def clean(value):
    if value is None:return '—'
    if isinstance(value,dict):return ', '.join(clean(v) for v in value.values() if v not in (None,'')) or '—'
    if isinstance(value,list):return ', '.join(clean(v) for v in value) or '—'
    return ''.join(c if c=='\n' or c.isprintable() else ' ' for c in str(value))

def table(rows):
    color=sys.stdout.isatty() and 'NO_COLOR' not in os.environ and os.environ.get('TERM')!='dumb'
    def paint(text,code):
        return f'\033[{code}m{text}\033[0m' if color else text
    label_width=max(len(k) for k,v in rows)
    width=max(24,min(90,shutil.get_terminal_size((100,24)).columns-label_width-7))
    border='+'+'-'*(label_width+2)+'+'+'-'*(width+2)+'+'
    edge=paint('|','2;36')
    print(paint(border,'2;36'))
    for key,value in rows:
        text=clean(value)
        style='0'
        if text=='—':style='2'
        elif key=='Status':
            state=text.lower()
            if state in ('approved','completed','succeeded','paid'):style='1;32'
            elif state in ('created','pending_approval','requires_action','pending'):style='1;33'
            elif state in ('expired','canceled','cancelled','failed','declined'):style='1;31'
            else:style='1;36'
        elif key in ('Card number','CVC','Expiration date'):style='1;33'
        elif key=='Merchant URL':style='4;34'
        elif key in ('Spend request ID','Brand'):style='35'
        elif key in ('Created at','Valid until'):style='36'
        lines=[]
        for line in text.splitlines() or ['—']:
            lines.extend(textwrap.wrap(line,width=width,replace_whitespace=False) or [''])
        for i,line in enumerate(lines):
            label=f'{key if i==0 else "":<{label_width}}'
            cell=f'{line:<{width}}'
            print(f'{edge} {paint(label,"1;36")} {edge} {paint(cell,style)} {edge}')
        print(paint(border,'2;36'))

def render(response,credentials=None,request_id=None):
    requests=[o for o in objects(response) if str(o.get('id','')).startswith('lsrq_')]
    request=requests[0] if requests else (response or credentials or {})
    card=credentials if credentials is not None else pick(request,'card') or {}
    expiry=pick(card,'expiration_date','expiry','expiration')
    month=pick(card,'exp_month','expiry_month','expiration_month')
    year=pick(card,'exp_year','expiry_year','expiration_year')
    if month is not None and year is not None:expiry=f'{str(month).zfill(2)}/{year}'
    address=pick(card,'billing_address') or pick(request,'billing_address')
    if address is None:
        billing=pick(card,'billing_details') or pick(request,'billing_details')
        if isinstance(billing,dict):address=billing.get('address')
    ident=pick(request,'id') if requests else request_id
    table([
      ('Spend request ID',ident or request_id),
      ('Status',pick(request,'status')),
      ('Merchant name',pick(request,'merchant_name')),
      ('Merchant URL',pick(request,'merchant_url')),
      ('Context',pick(request,'context')),
      ('Created at',pick(request,'created_at')),
      ('Card number',pick(card,'number','card_number','pan')),
      ('CVC',pick(card,'cvc','cvv','security_code')),
      ('Brand',pick(card,'brand','network')),
      ('Expiration date',expiry),
      ('Billing address',address),
      ('Valid until',pick(card,'valid_until','expires_at') or pick(request,'expires_at')),
    ])

if __name__=='__main__':
    with open(sys.argv[1]) as f:credentials=json.load(f)
    response={}
    if len(sys.argv)>2:
        try:
            with open(sys.argv[2]) as f:response=json.load(f)
        except (ValueError,OSError):pass
    render(response,credentials,sys.argv[3] if len(sys.argv)>3 else None)
