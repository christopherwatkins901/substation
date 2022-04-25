local conditionlib = import '../condition.libsonnet';
local processorlib = import '../process.libsonnet';

local event_created = 'event.created';
local event_hash = 'event.hash';

local processors = [
  // https://www.elastic.co/guide/en/ecs/current/ecs-event.html#field-event-hash
  {
    processors: [
      processorlib.hash('@this', event_hash),
    ],
  },
  // https://www.elastic.co/guide/en/ecs/current/ecs-event.html#field-event-created
  {
    processors: [
      processorlib.time('', event_created, 'now'),
    ],
  },
];

{
  processors: std.flattenArrays([p.processors for p in processors]),
}