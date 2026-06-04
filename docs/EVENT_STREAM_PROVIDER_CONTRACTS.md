# Event Stream provider contracts

## Purpose

Event stream provider facts describe topic/stream metadata, consumer group state, retention, and governance for systems such as Kafka, Pulsar, Kinesis, Pub/Sub, Event Hubs, or NATS without producing or consuming messages.

## Safety boundary

This is a fixture-first advisory provider contract. It returns normalized JSON facts only. It must not make live calls by default, mutate provider state, provision resources, return shell commands, or change queue dispatch/scheduling.

## Commands

```text
providers.d/event_stream/event_stream_provider.sh detect
providers.d/event_stream/event_stream_provider.sh topic explain
providers.d/event_stream/event_stream_provider.sh consumer explain
providers.d/event_stream/event_stream_provider.sh retention explain
providers.d/event_stream/event_stream_provider.sh governance explain
```

## Schemas

```text
queuebash.event_stream.detect.v1
queuebash.event_stream.topic.v1
queuebash.event_stream.consumer.v1
queuebash.event_stream.retention.v1
queuebash.event_stream.governance.v1
```

## Default fixtures

Default tests use `tests/fixtures/event_stream/` through `QUEUEBASH_EVENT_STREAM_FIXTURE_DIR`. No credentials are required.
