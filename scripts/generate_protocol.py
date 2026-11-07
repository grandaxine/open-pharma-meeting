"""Deterministic Open Pharma Meeting Protocol 0.1 draft artifacts."""
import json
from pathlib import Path
root=Path(__file__).resolve().parent.parent/'protocol/0.1'
base='https://openpharmameeting.invalid/protocol/0.1/'
def ref(name): return {'$ref':name+'.schema.json'}
def arr(item): return {'type':'array','items':item}
def enum(*values): return {'type':'string','enum':list(values)}
def obj(props, required=None): return {'type':'object','properties':props,'required':list(props) if required is None else required,'additionalProperties':True}
string={'type':'string'}; text={'type':'string','minLength':1}; uuid={'type':'string','format':'uuid'}; date={'type':'string','format':'date-time'}; version={'const':'0.1'}
integer={'type':'integer','minimum':0}; seconds={'type':'number','minimum':0}; https={'type':'string','format':'uri','pattern':'^https://'}
resource=obj({'visibility':enum('Private','Restricted','Organization'),'employeeIDs':arr(text)})
chunk=obj({'filename':{'type':'string','pattern':r'^[A-Za-z0-9_-][A-Za-z0-9_.-]{0,126}\.caf$'},'duration':{'type':'number','exclusiveMinimum':0,'maximum':86400},'sha256':{'type':'string','pattern':'^[a-fA-F0-9]{64}$'}})
schemas={
'TranscriptSegment':obj({'id':uuid,'start':seconds,'end':seconds,'text':string}),
'Transcript':obj({'schemaVersion':version,'meetingID':uuid,'language':text,'segments':arr(ref('TranscriptSegment'))}),
'RecordingMetadata':obj({'schemaVersion':version,'state':enum('ready','recording','paused','completed','interrupted'),'mediaType':{'const':'audio/x-caf'},'chunks':arr(chunk),'pendingFilename':chunk['properties']['filename']},['schemaVersion','state','mediaType','chunks']),
'AccessPolicy':obj({'schemaVersion':version,'revision':integer,'audio':resource,'transcript':resource,'reports':resource}),
'ReportArtifact':obj({'schemaVersion':version,'id':uuid,'meetingID':uuid,'type':text,'content':{'type':'object'},'requiresHumanReview':{'type':'boolean'}}),
'ProcessingJob':obj({'schemaVersion':version,'id':uuid,'meetingID':uuid,'state':enum('queued','running','succeeded','failed','cancelled')}),
'ProcessingResult':obj({'schemaVersion':version,'jobID':uuid,'reports':arr(ref('ReportArtifact'))}),
'AuditEvent':obj({'schemaVersion':version,'id':uuid,'occurredAt':date,'tenantID':text,'subjectID':text,'action':text,'resourceID':uuid,'outcome':enum('allowed','denied','failed'),'policyRevision':integer}),
'ConnectorCapabilities':obj({'schemaVersion':version,'protocolVersions':arr({'const':'0.1'}),'issuer':https,'apiBaseURL':https,'scopes':arr(text)}),
'Meeting':obj({'schemaVersion':version,'id':uuid,'createdAt':date,'title':text,'language':text,'consentAcknowledgedAt':date,'recording':ref('RecordingMetadata'),'transcript':ref('Transcript'),'accessPolicy':ref('AccessPolicy'),'reports':arr(ref('ReportArtifact')),'extensions':{'type':'object','propertyNames':{'pattern':r'^.+\..+$'},'additionalProperties':True}},['schemaVersion','id','createdAt','title','language','recording','accessPolicy','reports','extensions'])}
for name,schema in schemas.items():
    schema={'$schema':'https://json-schema.org/draft/2020-12/schema','$id':base+name+'.schema.json','title':name,**schema}
    (root/'schemas'/f'{name}.schema.json').write_text(json.dumps(schema,indent=2)+'\n')
uid='00000000-0000-4000-8000-000000000001'
policy={'schemaVersion':'0.1','revision':0,**{k:{'visibility':'Private','employeeIDs':[]} for k in ['audio','transcript','reports']}}
fixtures={
'TranscriptSegment':{'id':uid,'start':0,'end':1,'text':'Synthetic example'},
'Transcript':{'schemaVersion':'0.1','meetingID':uid,'language':'en-US','segments':[]},
'RecordingMetadata':{'schemaVersion':'0.1','state':'ready','mediaType':'audio/x-caf','chunks':[]},
'AccessPolicy':policy,
'ReportArtifact':{'schemaVersion':'0.1','id':uid,'meetingID':uid,'type':'org.example.training','content':{'summary':'Synthetic example'},'requiresHumanReview':True},
'ProcessingJob':{'schemaVersion':'0.1','id':uid,'meetingID':uid,'state':'queued'},
'ProcessingResult':{'schemaVersion':'0.1','jobID':uid,'reports':[]},
'AuditEvent':{'schemaVersion':'0.1','id':uid,'occurredAt':'2026-11-07T00:00:00Z','tenantID':'synthetic','subjectID':'synthetic','action':'report.read','resourceID':uid,'outcome':'allowed','policyRevision':0},
'ConnectorCapabilities':{'schemaVersion':'0.1','protocolVersions':['0.1'],'issuer':'https://identity.example.invalid','apiBaseURL':'https://gateway.example.invalid/v1','scopes':['meetings:read']}}
fixtures['Meeting']={'schemaVersion':'0.1','id':uid,'createdAt':'2026-11-07T00:00:00Z','title':'Synthetic example','language':'en-US','recording':fixtures['RecordingMetadata'],'accessPolicy':policy,'reports':[],'extensions':{}}
for name,f in fixtures.items(): (root/'fixtures'/f'{name}.json').write_text(json.dumps(f,indent=2)+'\n')

def body(schema): return {'required':True,'content':{'application/json':{'schema':schema}}}
def response(description,schema=None):
    result={'description':description}
    if schema: result['content']={'application/json':{'schema':schema}}
    return result
def api_ref(n): return {'$ref':f'#/components/schemas/{n}'}
error=obj({'code':text,'message':text,'requestID':uuid})
errors={str(c):response(d,error) for c,d in [(400,'Invalid request'),(401,'Authentication required'),(403,'Not authorized'),(404,'Not found or not visible'),(409,'Idempotency conflict or invalid state'),(412,'Policy/report revision mismatch'),(413,'Payload too large'),(429,'Rate limited; obey Retry-After'),(503,'Temporarily unavailable; obey Retry-After')]}
paths={}
def endpoint(path,method,operation,request=None,result=None,status='200',conditional=False,public=False):
    params=[]
    for key in ['meetingID','jobID','reportID']:
        if '{'+key+'}' in path: params.append({'name':key,'in':'path','required':True,'schema':uuid})
    if method in ['post','put']:
        params.append({'name':'Idempotency-Key','in':'header','required':True,'schema':uuid})
    if conditional: params.append({'name':'If-Match','in':'header','required':True,'schema':text})
    responses={status:response('Success',result),**errors}
    responses[status]['headers']={'ETag':{'description':'Opaque resource revision','schema':text}}
    if status=='202': responses[status]['headers'].update({'Location':{'description':'Job resource URL','schema':{'type':'string','format':'uri-reference'}},'Retry-After':{'description':'Poll delay in seconds','schema':integer}})
    op={'operationId':operation,'parameters':params,'responses':responses}
    if public: op['security']=[]
    if request: op['requestBody']=body(request)
    paths.setdefault(path,{})[method]=op
endpoint('/.well-known/open-pharma-meeting','get','discover',result=api_ref('ConnectorCapabilities'),public=True)
endpoint('/v1/meetings/{meetingID}/transcript','put','submitTranscript',request=api_ref('Transcript'),result=api_ref('Transcript'),status='201')
endpoint('/v1/meetings/{meetingID}/jobs','post','createJob',request=obj({'processingPolicyID':text}),result=api_ref('ProcessingJob'),status='202')
endpoint('/v1/jobs/{jobID}','get','getJob',result=api_ref('ProcessingJob'))
endpoint('/v1/jobs/{jobID}/result','get','getResult',result=api_ref('ProcessingResult'))
endpoint('/v1/meetings/{meetingID}/reports','get','listReports',result=obj({'items':arr(api_ref('ReportArtifact')),'nextCursor':string},['items']))
paths['/v1/meetings/{meetingID}/reports']['get']['parameters'] += [{'name':'cursor','in':'query','schema':string},{'name':'limit','in':'query','schema':{'type':'integer','minimum':1,'maximum':100,'default':50}}]
endpoint('/v1/meetings/{meetingID}/reports/{reportID}','put','syncReport',request=api_ref('ReportArtifact'),result=api_ref('ReportArtifact'),conditional=True)
endpoint('/v1/meetings/{meetingID}/access-policy','get','getPolicy',result=api_ref('AccessPolicy'))
endpoint('/v1/meetings/{meetingID}/access-policy','put','updatePolicy',request=api_ref('AccessPolicy'),result=api_ref('AccessPolicy'),conditional=True)
# Copy schemas with file refs rewritten to local OpenAPI component refs.
components=json.loads(json.dumps(schemas))
def rewrite(value):
    if isinstance(value,dict):
        if '$ref' in value: value['$ref']='#/components/schemas/'+value['$ref'].removesuffix('.schema.json')
        for v in value.values(): rewrite(v)
    elif isinstance(value,list):
        for v in value: rewrite(v)
rewrite(components)
api={'openapi':'3.1.0','info':{'title':'Open Pharma Meeting Protocol','version':'0.1.0','description':'Draft. Company-owned servers only. OIDC authorization code + PKCE S256 uses issuer discovery; no maintainer service or default server.'},'security':[{'companyBearer':[]}],'paths':paths,'components':{'securitySchemes':{'companyBearer':{'type':'http','scheme':'bearer','bearerFormat':'OAuth2 access token','description':'Company OIDC authorization code with PKCE S256. Validate audience, issuer, expiry and tenant membership; never use ID tokens as API tokens.'}},'schemas':components}}
(root/'openapi.json').write_text(json.dumps(api,indent=2)+'\n')
