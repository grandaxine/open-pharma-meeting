"""Language-independent fixture validation; requires jsonschema (dev dependency)."""
import copy, json, unittest
from pathlib import Path
from jsonschema import Draft202012Validator, FormatChecker
from referencing import Registry, Resource
ROOT=Path(__file__).resolve().parent.parent/'protocol/0.1'
SCHEMAS={p.stem.removesuffix('.schema'):json.loads(p.read_text()) for p in (ROOT/'schemas').glob('*.json')}
REGISTRY=Registry().with_resources((s['$id'], Resource.from_contents(s)) for s in SCHEMAS.values())
def validator(name): return Draft202012Validator(SCHEMAS[name],registry=REGISTRY,format_checker=FormatChecker())
class ProtocolTests(unittest.TestCase):
    def test_all_schemas_and_fixtures(self):
        self.assertEqual(len(SCHEMAS),10)
        for name,schema in SCHEMAS.items():
            with self.subTest(name=name):
                Draft202012Validator.check_schema(schema)
                validator(name).validate(json.loads((ROOT/'fixtures'/f'{name}.json').read_text()))
    def test_reject_future_version_and_invalid_policy(self):
        m=json.loads((ROOT/'fixtures/Meeting.json').read_text())
        m['schemaVersion']='1.0'; self.assertFalse(validator('Meeting').is_valid(m))
        m['schemaVersion']='0.1'; m['accessPolicy']['audio']['visibility']='Public'
        self.assertFalse(validator('Meeting').is_valid(m))
    def test_reject_negative_time_and_unsafe_filename(self):
        s=json.loads((ROOT/'fixtures/TranscriptSegment.json').read_text()); s['start']=-1
        self.assertFalse(validator('TranscriptSegment').is_valid(s))
        r=json.loads((ROOT/'fixtures/RecordingMetadata.json').read_text()); r['pendingFilename']='../secret.caf'
        self.assertFalse(validator('RecordingMetadata').is_valid(r))
    def test_openapi_refs_resolve(self):
        api=json.loads((ROOT/'openapi.json').read_text())
        def walk(v):
            if isinstance(v,dict):
                if '$ref' in v:
                    self.assertIn(v['$ref'].split('/')[-1],api['components']['schemas'])
                for child in v.values(): walk(child)
            elif isinstance(v,list):
                for child in v: walk(child)
        walk(api)
        self.assertFalse('servers' in api)
        for path,methods in api['paths'].items():
            for method,op in methods.items():
                if method in ('post','put'): self.assertTrue(any(p['name']=='Idempotency-Key' and p['required'] for p in op['parameters']))
if __name__=='__main__': unittest.main()
