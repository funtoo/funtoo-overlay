#!/usr/bin/python3

from google.cloud import storage

client = storage.Client.from_service_account_json('goog_creds.json')
print(list(client.list_buckets()))
myblob = client.blob("foo/bar/oni")
try:
    myblob.upload_from_file(f)
except GoogleCloudError:
    pass
