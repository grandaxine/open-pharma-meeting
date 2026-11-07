"""Validate a Swift-produced export with an independent JSON Schema implementation."""
import json, sys
from test_protocol import validator
validator('Meeting').validate(json.load(open(sys.argv[1])))
print('Swift-produced Meeting passes JSON Schema validation')
