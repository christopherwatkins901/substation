{
  defaults: {
    inspector: {
      content: {
        options: { type: null },
      },
      for_each: {
        options: { type: null, inspector: null },
      },
      ip: {
        options: { type: null },
      },
      json_schema: {
        options: { schema: null },
      },
      length: {
        options: { type: null, value: null, measurement: 'bytes' },
      },
      regexp: {
        options: { expression: null },
      },
      strings: {
        options: { type: null, expression: null },
      },
    },
    ip_database: {
      ip2location: {
        settings: { database: null },
      },
      maxmind_asn: {
        settings: { database: null, language: 'en' },
      },
      maxmind_city: {
        settings: { database: null, language: 'en' },
      },
    },
    processor: {
      aggregate: {
        options: { key: null, separator: null, max_count: 1000, max_size: 10000 },
      },
      aws_dynamodb: {
        options: { table: null, key_condition_expression: null, limit: 1, scan_index_forward: false },
      },
      aws_lambda: {
        options: { function_name: null },
      },
      base64: {
        options: { direction: null },
      },
      capture: {
        options: { expression: null, type: 'find', count: -1 },
      },
      case: {
        options: { type: null },
      },
      convert: {
        options: { type: null },
      },
      dns: {
        options: { type: null, timeout: 1000 },
      },
      domain: {
        options: { type: null },
      },
      flatten: {
        options: { deep: true },
      },
      for_each: {
        options: { processor: null },
      },
      group: {
        options: { keys: null },
      },
      gzip: {
        options: { direction: null },
      },
      hash: {
        options: { algorithm: 'sha256' },
      },
      insert: {
        options: { value: null },
      },
      join: {
        options: { separator: null },
      },
      math: {
        options: { operation: null },
      },
      pipeline: {
        options: { processors: null },
      },
      pretty_print: {
        options: { direction: null },
      },
      replace: {
        options: { old: null, new: null, count: -1 },
      },
      split: {
        options: { separator: null },
      },
      time: {
        options: { format: null, location: null, set_format: $.defaults.processor.time.set_format, set_location: null },
        set_format: '2006-01-02T15:04:05.000000Z',
      },
    },
    sink: {
      aws_dynamodb: {
        settings: { table: null, key: null }
      },
      aws_kinesis: {
        settings: { stream: null, partition: null, partition_key: null, shard_redistribution: false }
      },
      aws_kinesis_firehose: {
        settings: { stream: null },
      },
      aws_s3: {
        settings: { bucket: null, prefix: null, prefix_key: null },
      },
      aws_sqs: {
        settings: { queue: null }
      },
      grpc: {
        settings:{ server: null, timeout: null, certificate: null },
      },
      http: {
        settings: { url: null, headers: null, headers_key: null },
      },
      sumologic: {
        settings: { url: null, category: null, category_key: null },
      },
    },
  },
  helpers: {
    // if input is not an array, then this returns an array
    make_array(i): if !std.isArray(i) then [i] else i,
    key: {
      // if key is foo and arr is bar, then result is foo.bar
      // if key is foo and arr is [bar, baz], then result is foo.bar.baz
      append(key, arr): std.join('.', $.helpers.make_array(key) + $.helpers.make_array(arr)),
      // if key is foo, then result is foo.-1
      append_array(key): key + '.-1',
      // if key is foo and e is 0, then result is foo.0
      get_element(key, e=0): std.join('.', [key, if std.isNumber(e) then std.toString(e) else e]),
    },
    inspector: {
      // validates base settings of any inspector by checking for the
      // existence of any fields except key and negate
      validate(settings): std.all([
        if !std.member(['key', 'negate'], x) then false else true
        for x in std.objectFields(settings)
      ]),
    },
    // dynamically flattens processor configurations
    flatten_processors(processor): std.flattenArrays([
      if std.objectHas(p, 'processor') then
        if std.isArray(p.processor) then p.processor
        else [p.processor]
      else [p]

      for p in $.helpers.make_array(processor)
    ]),
  },
  interfaces: {
    // mirrors interfaces from the condition package
    operator: {
      all(i): { operator: 'all', inspectors: if !std.isArray(i) then [i] else i },
      any(i): { operator: 'any', inspectors: if !std.isArray(i) then [i] else i },
      none(i): { operator: 'none', inspectors: if !std.isArray(i) then [i] else i },
    },
    inspector: {
      settings: { key: null, negate: null },
      content(options=$.defaults.inspector.content.options,
              settings=$.interfaces.inspector.settings): {
        local opt = std.mergePatch($.defaults.inspector.content.options, options),

        assert options != {} : 'invalid inspector options',
        assert $.helpers.inspector.validate(settings) : 'invalid inspector settings',
        local s = std.mergePatch($.interfaces.inspector.settings, settings),

        type: 'content',
        settings: std.mergePatch({ options: opt }, s),
      },
      for_each(options=$.defaults.inspector.for_each.options,
               settings=$.interfaces.inspector.settings): {
        local opt = std.mergePatch($.defaults.processor.inspector.for_each.options, options),

        assert $.helpers.inspector.validate(settings) : 'invalid inspector settings',
        local s = std.mergePatch($.interfaces.inspector.settings, settings),

        type: 'for_each',
        settings: std.mergePatch({ options: opt }, s),
      },
      ip(options=$.defaults.inspector.ip.options,
         settings=$.interfaces.inspector.settings): {
        local opt = std.mergePatch($.defaults.inspector.ip.options, options),

        assert $.helpers.inspector.validate(settings) : 'invalid inspector settings',
        local s = std.mergePatch($.interfaces.inspector.settings, settings),

        type: 'ip',
        settings: std.mergePatch({ options: opt }, s),
      },
      json_schema(options=$.defaults.inspector.json_schema.options,
                  settings=$.interfaces.inspector.settings): {
        local opt = std.mergePatch($.defaults.inspector.json_schema.options, options),

        assert $.helpers.inspector.validate(settings) : 'invalid inspector settings',
        local s = std.mergePatch($.interfaces.inspector.settings, settings),

        type: 'json_schema',
        settings: std.mergePatch({ options: opt }, s),
      },
      json_valid(settings=$.interfaces.inspector.settings): {
        assert $.helpers.inspector.validate(settings) : 'invalid inspector settings',
        local s = std.mergePatch($.interfaces.inspector.settings, settings),

        type: 'json_valid',
        settings: s,
      },
      length(options=$.defaults.inspector.length.options,
             settings=$.interfaces.inspector.settings): {
        local opt = std.mergePatch($.defaults.inspector.length.options, options),

        assert $.helpers.inspector.validate(settings) : 'invalid inspector settings',
        local s = std.mergePatch($.interfaces.inspector.settings, settings),

        type: 'length',
        settings: std.mergePatch({ options: opt }, s),
      },
      random: {
        type: 'random',
      },
      regexp(options=$.defaults.inspector.regexp.options,
             settings=$.interfaces.inspector.settings): {
        local opt = std.mergePatch($.defaults.inspector.regexp.options, options),

        assert $.helpers.inspector.validate(settings) : 'invalid inspector settings',
        local s = std.mergePatch($.interfaces.inspector.settings, settings),

        type: 'regexp',
        settings: std.mergePatch({ options: opt }, s),
      },
      strings(options=$.defaults.inspector.strings.options,
              settings=$.interfaces.inspector.settings): {
        local opt = std.mergePatch($.defaults.inspector.strings.options, options),

        assert $.helpers.inspector.validate(settings) : 'invalid inspector settings',
        local s = std.mergePatch($.interfaces.inspector.settings, settings),

        type: 'strings',
        settings: std.mergePatch({ options: opt }, s),
      },
    },
    // mirrors interfaces from the process package
    processor: {
      settings: { key: null, set_key: null, condition: null, ignore_close: null, ignore_errors: null },
      aggregate(options=$.defaults.processor.aggregate.options,
                settings=$.interfaces.processor.settings): {
        local opt = std.mergePatch($.defaults.processor.aggregate.options, options),
        local s = std.mergePatch($.interfaces.processor.settings, settings),

        type: 'aggregate',
        settings: std.mergePatch({ options: opt }, s),
      },
      aws_dynamodb(options=$.defaults.processor.aws_dynamodb.options,
                   settings=$.interfaces.processor.settings): {
        local opt = std.mergePatch($.defaults.processor.aws_dynamodb.options, options),
        local s = std.mergePatch($.interfaces.processor.settings, settings),

        type: 'aws_dynamodb',
        settings: std.mergePatch({ options: opt }, s),
      },
      aws_lambda(options=$.defaults.processor.aws_lambda.options,
                 settings=$.interfaces.processor.settings): {
        local opt = std.mergePatch($.defaults.processor.aws_lambda.options, options),
        local s = std.mergePatch($.interfaces.processor.settings, settings),

        type: 'aws_lambda',
        settings: std.mergePatch({ options: opt }, s),

      },
      base64(options=$.defaults.processor.base64.options,
             settings=$.interfaces.processor.settings): {
        local opt = std.mergePatch($.defaults.processor.base64.options, options),
        local s = std.mergePatch($.interfaces.processor.settings, settings),

        type: 'base64',
        settings: std.mergePatch({ options: opt }, s),
      },
      capture(options=$.defaults.processor.capture.options,
              settings=$.interfaces.processor.settings): {
        local opt = std.mergePatch($.defaults.processor.capture.options, options),
        local s = std.mergePatch($.interfaces.processor.settings, settings),

        type: 'capture',
        settings: std.mergePatch({ options: opt }, s),
      },
      case(options=$.defaults.processor.case.options,
           settings=$.interfaces.processor.settings): {
        local opt = std.mergePatch($.defaults.processor.case.options, options),
        local s = std.mergePatch($.interfaces.processor.settings, settings),

        type: 'case',
        settings: std.mergePatch({ options: opt }, s),
      },
      convert(options=$.defaults.processor.convert.options,
              settings=$.interfaces.processor.settings): {
        local opt = std.mergePatch($.defaults.processor.convert.options, options),
        local s = std.mergePatch($.interfaces.processor.settings, settings),

        type: 'convert',
        settings: std.mergePatch({ options: opt }, s),
      },
      copy(settings=$.interfaces.processor.settings): {
        local s = std.mergePatch($.interfaces.processor.settings, settings),

        type: 'copy',
        settings: s,
      },
      delete(settings=$.interfaces.processor.settings): {
        local s = std.mergePatch($.interfaces.processor.settings, settings),

        type: 'delete',
        settings: s,
      },
      dns(options=$.defaults.processor.dns.options,
          settings=$.interfaces.processor.settings): {
        local opt = std.mergePatch($.defaults.processor.dns.options, options),
        local s = std.mergePatch($.interfaces.processor.settings, settings),

        type: 'dns',
        settings: std.mergePatch({ options: opt }, s),
      },
      domain(options=$.defaults.processor.domain.options,
             settings=$.interfaces.processor.settings): {
        local opt = std.mergePatch($.defaults.processor.domain.options, options),
        local s = std.mergePatch($.interfaces.processor.settings, settings),

        type: 'domain',
        settings: std.mergePatch({ options: opt }, s),
      },
      drop(settings=$.interfaces.processor.settings): {
        local s = std.mergePatch($.interfaces.processor.settings, settings),

        type: 'drop',
        settings: settings,
      },
      expand(settings=$.interfaces.processor.settings): {
        local s = std.mergePatch($.interfaces.processor.settings, settings),

        type: 'expand',
        settings: settings,
      },
      flatten(options=$.defaults.processor.flatten.options,
              settings=$.interfaces.processor.settings): {
        local opt = std.mergePatch($.defaults.processor.flatten.options, options),
        local s = std.mergePatch($.interfaces.processor.settings, settings),

        type: 'flatten',
        settings: std.mergePatch({ options: opt }, s),
      },
      for_each(options=$.defaults.processor.for_each.options,
               settings=$.interfaces.processor.settings): {
        local opt = std.mergePatch($.defaults.processor.for_each.options, options),
        local s = std.mergePatch($.interfaces.processor.settings, settings),

        type: 'for_each',
        settings: std.mergePatch({ options: opt }, s),
      },
      group(options=$.defaults.processor.group.options,
            settings=$.interfaces.processor.settings): {
        local opt = std.mergePatch($.defaults.processor.group.options, options),
        local s = std.mergePatch($.interfaces.processor.settings, settings),

        type: 'group',
        settings: std.mergePatch({ options: opt }, s),
      },
      gzip(options=$.defaults.gzip.capture.options,
           settings=$.interfaces.processor.settings): {
        local opt = std.mergePatch($.defaults.processor.gzip.options, options),
        local s = std.mergePatch($.interfaces.processor.settings, settings),

        type: 'gzip',
        settings: std.mergePatch({ options: opt }, s),
      },
      hash(options=$.defaults.processor.hash.options,
           settings=$.interfaces.processor.settings): {
        local opt = std.mergePatch($.defaults.processor.hash.options, options),
        local s = std.mergePatch($.interfaces.processor.settings, settings),

        type: 'hash',
        settings: std.mergePatch({ options: opt }, s),
      },
      insert(options=$.defaults.processor.insert.options,
             settings=$.interfaces.processor.settings): {
        local opt = std.mergePatch($.defaults.processor.insert.options, options),
        local s = std.mergePatch($.interfaces.processor.settings, settings),

        type: 'insert',
        settings: std.mergePatch({ options: opt }, s),
      },
      ip_database(options=$.defaults.processor.insert.options,
                  settings=$.interfaces.processor.settings): {
        local s = std.mergePatch($.interfaces.processor.settings, settings),

        type: 'ip_database',
        settings: std.mergePatch({ options: options }, s),
      },
      join(options=$.defaults.processor.join.options,
           settings=$.interfaces.processor.settings): {
        local opt = std.mergePatch($.defaults.processor.join.options, options),
        local s = std.mergePatch($.interfaces.processor.settings, settings),

        type: 'join',
        settings: std.mergePatch({ options: opt }, s),
      },
      math(options=$.defaults.processor.math.options,
           settings=$.interfaces.processor.settings): {
        local opt = std.mergePatch($.defaults.processor.math.options, options),
        local s = std.mergePatch($.interfaces.processor.settings, settings),

        type: 'math',
        settings: std.mergePatch({ options: opt }, s),
      },
      pipeline(options=$.defaults.processor.pipeline.options,
               settings=$.interfaces.processor.settings): {
        local opt = std.mergePatch($.defaults.processor.pipeline.options, options),
        local s = std.mergePatch($.interfaces.processor.settings, settings),

        type: 'pipeline',
        settings: std.mergePatch({ options: opt }, s),
      },
      pretty_print(options=$.defaults.processor.direction.options,
                   settings=$.interfaces.processor.settings): {
        local opt = std.mergePatch($.defaults.processor.direction.options, options),
        local s = std.mergePatch($.interfaces.processor.settings, settings),

        type: 'pretty_print',
        settings: std.mergePatch({ options: opt }, s),
      },
      replace(options=$.defaults.processor.replace.options,
              settings=$.interfaces.processor.settings): {
        local opt = std.mergePatch($.defaults.processor.replace.options, options),
        local s = std.mergePatch($.interfaces.processor.settings, settings),

        type: 'replace',
        settings: std.mergePatch({ options: opt }, s),
      },
      split(options=$.defaults.processor.split.options,
            settings=$.interfaces.processor.settings): {
        local opt = std.mergePatch($.defaults.processor.split.options, options),
        local s = std.mergePatch($.interfaces.processor.settings, settings),

        type: 'split',
        settings: std.mergePatch({ options: opt }, s),
      },
      time(options=$.defaults.processor.time.options,
           settings=$.interfaces.processor.settings): {
        local opt = std.mergePatch($.defaults.processor.time.options, options),
        local s = std.mergePatch($.interfaces.processor.settings, settings),

        type: 'time',
        settings: std.mergePatch({ options: opt }, s),
      },
    },
    // mirrors interfaces from the internal/sink package
    sink: {
      aws_dynamodb(settings=$.defaults.sink.aws_dynamodb.settings): {
        local s = std.mergePatch($.defaults.sink.aws_dynamodb.settings, settings),

        type: 'aws_dynamodb',
        settings: s,
      },
      aws_kinesis(settings=$.defaults.sink.aws_kinesis.settings): {
        local s = std.mergePatch($.defaults.sink.aws_kinesis.settings, settings),

        type: 'aws_kinesis',
        settings: s,
      },
      aws_kinesis_firehose(settings=$.defaults.sink.aws_kinesis_firehose.settings): {
        local s = std.mergePatch($.defaults.sink.aws_kinesis_firehose.settings, settings),

        type: 'aws_kinesis_firehose',
        settings: s,
      },
      aws_s3(settings=$.defaults.sink.aws_s3.settings): {
        local s = std.mergePatch($.defaults.sink.aws_s3.settings, settings),

        type: 'aws_s3',
        settings: s,
      },
      aws_sqs(settings=$.defaults.sink.aws_sqs.settings): {
        local s = std.mergePatch($.defaults.sink.aws_sqs.settings, settings),

        type: 'aws_sqs',
        settings: s,
      },
      grpc(settings=$.defaults.sink.grpc.settings): {
        local s = std.mergePatch($.defaults.sink.grpc.settings, settings),

        type: 'grpc',
        settings: s,
      },
      http(settings=$.defaults.sink.http.settings): {
        local s = std.mergePatch($.defaults.sink.http.settings, settings),

        type: 'http',
        settings: s,
      },
      stdout: {
        type: 'stdout',
      },
      sumologic(settings=$.defaults.sink.sumologic.settings): {
        local s = std.mergePatch($.defaults.sink.sumologic.settings, settings),

        type: 'sumologic',
        settings: s,
      },
    },
    // mirrors interfaces from the internal/ip_database/database package
    ip_database: {
      ip2location(settings=$.defaults.ip_database.ip2location.settings): {
        local s = std.mergePatch($.defaults.ip_database.ip2location.settings, settings),

        type: 'ip2location',
        settings: s,
      },
      maxmind_asn(settings=$.defaults.ip_database.maxmind_asn.settings): {
        local s = std.mergePatch($.defaults.ip_database.maxmind_asn.settings, settings),

        type: 'maxmind_asn',
        settings: s,
      },
      maxmind_city(settings=$.defaults.ip_database.maxmind_city.settings): {
        local s = std.mergePatch($.defaults.ip_database.maxmind_city.settings, settings),

        type: 'maxmind_city',
        settings: s,
      },
    },
  },
  patterns: {
    inspector: {
      // negates any inspector
      negate(inspector): std.mergePatch(inspector, { settings: { negate: true } }),
      ip: {
        // checks if an IP address is private.
        //
        // use with the ANY operator to match private IP addresses.
        // use with the NONE operator to match public IP addresses.
        private(key=null): [
          $.interfaces.inspector.ip(options={ type: 'loopback' }, settings={ key: key }),
          $.interfaces.inspector.ip(options={ type: 'multicast' }, settings={ key: key }),
          $.interfaces.inspector.ip(options={ type: 'multicast_link_local' }, settings={ key: key }),
          $.interfaces.inspector.ip(options={ type: 'private' }, settings={ key: key }),
          $.interfaces.inspector.ip(options={ type: 'unicast_link_local' }, settings={ key: key }),
          $.interfaces.inspector.ip(options={ type: 'unspecified' }, settings={ key: key }),
        ],
      },
      length: {
        // checks if data is equal to zero.
        //
        // use with the ANY / ALL operator to match empty data.
        // use with the NONE operator to match non-empty data.
        eq_zero(key=null):
          $.interfaces.inspector.length(options={ type: 'equals', value: 0 }, settings={ key: key }),
        // checks if data is greater than zero.
        //
        // use with the ANY / ALL operator to match non-empty data.
        // use with the NONE operator to match empty data.
        gt_zero(key=null):
          $.interfaces.inspector.length(options={ type: 'greater_than', value: 0 }, settings={ key: key }),
      },
      strings: {
        contains(expression, key=null):
          $.interfaces.inspector.strings(options={ type: 'contains', expression: expression }, settings={ key: key }),
        equals(expression, key=null):
          $.interfaces.inspector.strings(options={ type: 'equals', expression: expression }, settings={ key: key }),
        starts_with(expression, key=null):
          $.interfaces.inspector.strings(options={ type: 'starts_with', expression: expression }, settings={ key: key }),
        ends_with(expression, key=null):
          $.interfaces.inspector.strings(options={ type: 'ends_with', expression: expression }, settings={ key: key }),
      },
    },
    operator: {
      ip: {
        // returns true if the key is a valid IP address and is not private
        public(key=null): $.interfaces.operator.none(
          $.patterns.inspector.ip.private(key=key)
          + [
            // the none operator combined with negation returns true if the key is a valid IP
            $.interfaces.inspector.ip(options={ type: 'valid' }, settings={ key: key, negate: true }),
          ]
        ),
        // returns true if the key is a private IP address
        private(key=null): $.interfaces.operator.any($.patterns.inspector.ip.private(key=key)),
      },
    },
    processor: {
      // replaces a condition in one or more processors.
      //
      // by default this will not replace a condition if the
      // processor(s) have no condition, but this can be overriden
      // by setting force to true.
      replace_condition(processor, condition, force=false): {
        local p = if !std.isArray(processor)
        then [processor]
        else processor,

        processor: [
          if force || std.objectHas(p.settings, 'condition')
          then std.mergePatch(p, { settings: { condition: condition } })
          else p

          for p in $.helpers.flatten_processors(p)
        ],
      },
      // executes one or more processors if key is not empty.
      //
      // if negate is set to true, then this executes the processor(s)
      // if key is empty.
      if_not_empty(processor, key, set_key=null, negate=false): {
        local i = if negate == false
        then $.patterns.inspector.length.gt_zero(key=key)
        else $.patterns.inspector.length.eq_zero(key=key),
        local c = $.interfaces.operator.all(i),

        processor: $.helpers.flatten_processors(
          $.patterns.processor.replace_condition(processor, c, force=true)
        ),
      },
      // performs a "move" by copying and deleting keys.
      move(key, set_key, condition=null): {
        processor: $.interfaces.processor.pipeline(
          // @this requires special handling because the delete processor cannot
          // delete complex objects.
          //
          // this works by copying the object into a metadata key, replacing the
          // object with empty data, then copying the metadata key into the
          // object.
          options={processors:
          if key == '@this'
          then [
            $.interfaces.processor.copy(settings={ set_key: '!metadata move' }),
            $.interfaces.processor.copy(settings={ key: '!metadata __null' }),
            $.interfaces.processor.copy(settings={ key: '!metadata move', set_key: set_key }),
          ]
          else [
            $.interfaces.processor.copy(settings={ key: key, set_key: set_key }),
            $.interfaces.processor.delete(settings={ key: key }),
          ]},
          settings={ condition: condition },
        ),
      },
      copy: {
        // copies one or more keys into an array.
        //
        // apply a condition using the pipeline processor:
        //  local c = foo,
        //  local p = $.interfaces.processor.pipeline(processors=into_array(...).processors, condition=c),
        //  processor: $.interfaces.processor.apply(p)
        //
        // embed within other processor arrays by appending:
        //  processors: [
        //    ...,
        //    ...,
        // ] + into_array(...).processors
        into_array(keys, set_key, condition=null): {
          local opts = $.interfaces.processor.copy,

          processor: $.interfaces.processor.pipeline(
            options={processors:[
            $.interfaces.processor.copy(settings={ key: key, set_key: $.helpers.key.append_array(set_key) })
            for key in keys
          ]}, settings={ condition: condition }),
        },
      },
      dns: {
        // queries the Team Cymru Malware Hash Registry (https://www.team-cymru.com/mhr).
        //
        // MHR enriches hash data with a summary of results from anti-virus engines.
        // this patterns will cause significant latency in a data pipeline and should
        // be used in combination with a caching deployment patterns
        query_team_cymru_mhr(key, set_key='!metadata dns.query_team_cymru_mhr', condition=null): {
          local mhr_query = '!metadata query_team_cymru_mhr',
          local mhr_response = '!metadata response_team_cymru_mhr',

          processor: $.interfaces.processor.pipeline(
            options={processors:[
            // creates the MHR query domain by concatenating the key with the MHR service domain
            $.interfaces.processor.copy(
              settings={ key: key, set_key: $.helpers.key.append_array(mhr_query) }
            ),
            $.interfaces.processor.insert(
              options={ value: 'hash.cymru.com' },
              settings={ set_key: $.helpers.key.append_array(mhr_query) }
            ),
            $.interfaces.processor.join(
              options={ separator: '.' },
              settings={ key: mhr_query, set_key: mhr_query }
            ),
            // performs MHR query and parses returned value `["epoch" "hits"]` into object `{"team_cymru":{"epoch":"", "hits":""}}`
            $.interfaces.processor.dns(
              options={ type: 'query_txt' },
              settings={ key: mhr_query, set_key: mhr_response }
            ),
            $.interfaces.processor.split(
              options={ separator: ' ' },
              settings={ key: $.helpers.key.get_element(mhr_response, 0), set_key: mhr_response }
            ),
            $.interfaces.processor.copy(
              settings={ key: $.helpers.key.get_element(mhr_response, 0), set_key: $.helpers.key.append(set_key, 'epoch') }
            ),
            $.interfaces.processor.copy(
              settings={ key: $.helpers.key.get_element(mhr_response, 1), set_key: $.helpers.key.append(set_key, 'hits') }
            ),
            // converts values from strings to integers
            $.interfaces.processor.convert(
              options={ type: 'int' },
              settings={
                key: $.helpers.key.append(set_key, 'epoch'),
                set_key: $.helpers.key.append(set_key, 'epoch'),
              }
            ),
            $.interfaces.processor.convert(
              options={ type: 'int' },
              settings={
                key: $.helpers.key.append(set_key, 'hits'),
                set_key: $.helpers.key.append(set_key, 'hits'),
              }
            ),
            // delete remaining keys
            $.interfaces.processor.delete(settings={ key: mhr_query }),
            $.interfaces.processor.delete(settings={ key: mhr_response }),
          ]}, settings={ condition: condition }),
        },
      },
      drop: {
        // randomly drops data.
        //
        // this can be used for integration testing when full load is not required.
        random: {
          local c = $.interfaces.operator.all($.interfaces.inspector.random),
          processor: $.interfaces.processor.drop(settings={ condition: c }),
        },
      },
      hash: {
        // hashes data using the SHA-256 algorithm.
        //
        // this patterns dynamically supports objects, plaintext data, and binary data.
        data(set_key='!metadata hash.data', algorithm='sha256'): {
          local hash_opts = { algorithm: algorithm },

          // where data is temporarily stored during hashing
          local key = '!metadata data',

          local is_plaintext = $.interfaces.inspector.content(options={ type: 'text/plain; charset=utf-8' }, settings={ key: key }),
          local is_json = $.interfaces.inspector.json_valid(),
          local not_json = $.interfaces.inspector.json_valid(settings={ negate: true }),

          processor: [
            // copies data to metadata for hashing
            $.interfaces.processor.copy(settings={ set_key: key }),
            // if data is an object, then hash its contents
            $.interfaces.processor.hash(hash_opts,
                                        settings={ key: '@this', set_key: set_key, condition: $.interfaces.operator.all([is_plaintext, is_json]) }),
            // if data is not an object but is plaintext, then hash it without decoding
            $.interfaces.processor.hash(hash_opts,
                                        settings={ key: key, set_key: set_key, condition: $.interfaces.operator.all([is_plaintext, not_json]) }),
            // if data is not plaintext, then decode and hash it
            $.interfaces.processor.pipeline(
              options={ processors: [
              $.interfaces.processor.base64(options={ direction: 'from' }),
              $.interfaces.processor.hash(hash_opts),
            ] }, 
            settings={ key: key, set_key: set_key, condition: $.interfaces.operator.none([is_plaintext]) }
            ),
            // delete copied data
            $.interfaces.processor.delete(settings={ key: key }),
          ],
        },
      },
      ip_database: {
        // performs lookup for any public IP address in any IP enrichment database.
        lookup_address(key, set_key='!metadata ip_database.lookup_address', options=null): {
          assert options != null : 'ip_database.lookup_address options cannot be null',

          // only performs lookups against public IP addresses
          local c = $.patterns.operator.ip.public(key),

          processor: $.interfaces.processor.ip_database(
            options,
            settings={ key: key, set_key: set_key, condition: c }
          ),
        },
      },
      time: {
        // generates current time.
        now(set_key='!metadata time.now', set_format=$.defaults.processor.time.set_format, condition=null): {
          processor: $.interfaces.processor.time(
            options={ format: 'now', set_format: set_format },
            settings={ set_key: set_key, condition: condition }
          ),
        },
      },
    },
  },
}