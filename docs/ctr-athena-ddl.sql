-- Starter Athena table over Amazon Connect Contact Trace Records (CTR)
-- delivered by Kinesis Firehose into the analytics bucket as gzipped JSON.
-- Replace BUCKET_NAME and run in Athena against the "connect_reporting" database.
-- This is a starter column set — CTRs carry many more fields; extend the table
-- or run a Glue crawler in production. Partition keys match the Firehose prefix.

CREATE EXTERNAL TABLE IF NOT EXISTS ctr_records (
  contactid string,
  awsaccountid string,
  agentusername string,
  channel string,
  initiationmethod string,
  instancearn string,
  queuename string,
  initiationtimestamp string,
  disconnecttimestamp string,
  totalpausedduration int,
  customerendpoint struct<address:string,type:string>,
  attributes map<string,string>
)
PARTITIONED BY (year string, month string, day string)
ROW FORMAT SERDE 'org.openx.data.jsonserde.JsonSerDe'
STORED AS TEXTFILE
LOCATION 's3://BUCKET_NAME/ctr/';

-- After creating the table, load the Firehose partitions:
-- MSCK REPAIR TABLE ctr_records;
--
-- First questions this answers (the supervisor's day-one list):
--   SELECT queuename, count(*) AS contacts
--   FROM ctr_records GROUP BY queuename ORDER BY contacts DESC;
--   SELECT date_trunc('hour', from_iso8601_timestamp(initiationtimestamp)) AS hr, count(*)
--   FROM ctr_records GROUP BY 1 ORDER BY 1;
