# Setup table

Create the table using the console:

```
Table name: profile

Columns:

id: Integer auto-increment
name: Text
address: Text
lat: Numeric, Nullable
lng: Numeric, Nullable
```

# Deploy Google Cloud Function

Deploy the function:

```bash
gcloud beta functions deploy python-echo \
       --runtime python37 \
       --trigger-http
```

Get the trigger URL:
```yaml
httpsTrigger:
  url: https://us-central1-hasura-test.cloudfunctions.net/python-echo
```

Open Hasura console, goto `Events -> Add Trigger` and create a new trigger:
```
Trigger name: profile_change
Schema/Table: public/profile
Operations: Insert, Update, Delete
Webhook URL: [Trigger URL]
```

Once the trigger is created, goto `Data -> profile -> Insert row` and add a row. 
