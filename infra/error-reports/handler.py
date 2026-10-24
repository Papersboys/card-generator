import base64,json,os,re,uuid,datetime
import boto3
s3=boto3.client('s3')
KINDS={'authorization','minimum_amount','approval','network','server','other'}
def handler(event,context):
    def reply(status,data):return {'statusCode':status,'headers':{'content-type':'application/json'},'body':json.dumps(data)}
    if event.get('requestContext',{}).get('http',{}).get('method')!='POST':return reply(405,{'error':'POST required'})
    try:
        raw=event.get('body','')
        if event.get('isBase64Encoded'):raw=base64.b64decode(raw).decode('utf-8')
        if len(raw)>1024:return reply(413,{'error':'Report too large'})
        data=json.loads(raw)
        if not isinstance(data,dict) or set(data)!={'schema','app_version','os_version','category','http_status'}:raise ValueError()
        if data['schema']!=1 or data['category'] not in KINDS:raise ValueError()
        for k in ('app_version','os_version'):
            if not isinstance(data[k],str) or not re.fullmatch(r'[0-9.]{1,24}',data[k]):raise ValueError()
        status=data['http_status']
        if type(status)!=int or (status!=0 and not 100<=status<=599):raise ValueError()
    except (ValueError,TypeError,UnicodeError):return reply(400,{'error':'Invalid report'})
    now=datetime.datetime.now(datetime.timezone.utc)
    ident=str(uuid.uuid4())
    # No raw request, IP, user agent, payment data, or credentials are stored.
    report={k:data[k] for k in ('schema','app_version','os_version','category','http_status')}
    report.update(report_id=ident,received_at=now.isoformat())
    s3.put_object(Bucket=os.environ['REPORT_BUCKET'],Key=f'reports/{now:%Y/%m/%d}/{ident}.json',Body=json.dumps(report).encode(),ContentType='application/json',ServerSideEncryption='AES256')
    return reply(201,{'report_id':ident})
