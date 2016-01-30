# norikra-helper

norikra-helper is norikra-client plus some utility commands.

## Installation

This program is not released to Rubygems yet.

Clone this repository and use it from command line.

```
git clone https://github.com/ogibayashi/norikra-helper.git
cd norikra-helper
bundle install
bundle exec bin/norikra-helper [arguments ... ]
```

## Usage

norikra-helper extends norikra-client CLI, so it can be used just as a replacement of norikra-client CLI, and have some additional commands below.

### Test query

Register query to Norikra with temporary name and periodically fetch results. It is useful for just trying query to see how it works.

```
norikra-helper query test <query statement>
```

Example:

```
% norikra-helper query test "select count(*) as cnt from teststream.win:time_batch(1 sec)" 
Registered query: norikra-tmp-22596_1449125093
{"time":"2015/12/03 15:46:01","cnt":12}
{"time":"2015/12/03 15:46:02","cnt":3}
{"time":"2015/12/03 15:46:03","cnt":5}
{"time":"2015/12/03 15:46:04","cnt":103}
{"time":"2015/12/03 15:46:05","cnt":1535}
{"time":"2015/12/03 15:46:06","cnt":2309}
(output continues as long as events come in and you do not enter Ctrl-C)
```

For command line options, try `norikra-helper query test --help`

### Replace query

Replace query statement with the query name with new one. It actually just remove and re-register.

```
norikra-helper query replace <query name> <query statement>
```

Example:
(norikra-helper extends Norikra::Client::CLI, so it can be used as norikra-client.)

```
 ### List current query.
% ./norikra-helper query add testquery1 "select uri, count(*) as cnt from teststream.win:time_batch(1 sec) group by uri"
 % ./norikra-helper query list
NAME    GROUP   TARGETS SUSPENDED       QUERY
testquery1      default teststream      false   select uri, count(*) as cnt from teststream.win:time_batch(1 sec) group by uri
1 queries found.

 ### Replace the statement.
% ./norikra-helper query replace testquery1  "select method, count(*) as cnt from teststream.win:time_batch(1 sec) group by method"
Replacing query <testquery1>, old_expression: select uri, count(*) as cnt from teststream.win:time_batch(1 sec) group by uri, new_expression: select method, count(*) as cnt from teststream.win:time_batch(1 sec) group by method


 ### Replaced
% ./norikra-helper query list
NAME    GROUP   TARGETS SUSPENDED       QUERY
testquery1      default teststream      false   select method, count(*) as cnt from teststream.win:time_batch(1 sec) group by method
1 queries found.
```

### Replay events

Just sends events in the file to Norikra as specified target.

```
norikra-helper event replay <target> <file>
```

Events in the file are JSON format, and you can also specifiy sleep seconds with `# <number>` format between events.

```
{"id":"0000","time":"[2015-12-03","15":"42:03]","level":"DEBUG","method":"POST","uri":"/api/v1/people","reqtime":"3.053540515830725","foobar":"dNjtvYKx"}
# 1
{"id":"0001","time":"[2015-12-03","15":"42:03]","level":"WARN","method":"GET","uri":"/api/v1/people","reqtime":"1.4360158435718304","foobar":"bMNxUyrL"}
{"id":"0002","time":"[2015-12-03","15":"42:03]","level":"INFO","method":"POST","uri":"/api/v1/people","reqtime":"0.5269335558815027","foobar":"ZqZfpVas"}
{"id":"0003","time":"[2015-12-03","15":"42:03]","level":"ERROR","method":"GET","uri":"/api/v1/textdata","reqtime":"2.3612488783081855","foobar":"ttoNGbj5"}
# 5
{"id":"0004","time":"[2015-12-03","15":"42:03]","level":"ERROR","method":"GET","uri":"/api/v1/textdata","reqtime":"0.6189472719635449","foobar":"xJlY3CIa"}
{"id":"0005","time":"[2015-12-03","15":"42:03]","level":"DEBUG","method":"GET","uri":"/api/v1/textdata","reqtime":"0.8334068332564243","foobar":"O0rpePQ6"}
{"id":"0006","time":"[2015-12-03","15":"42:03]","level":"ERROR","method":"GET","uri":"/api/v1/textdata","reqtime":"3.518392857673223","foobar":"P5JM3lUs"}
# 10
{"id":"0007","time":"[2015-12-03","15":"42:03]","level":"ERROR","method":"GET","uri":"/api/v1/people","reqtime":"3.0783702672650537","foobar":"m5Qulege"}
{"id":"0008","time":"[2015-12-03","15":"42:03]","level":"ERROR","method":"GET","uri":"/api/v1/textdata","reqtime":"4.976967872213626","foobar":"0OopuJ6x"}
{"id":"0009","time":"[2015-12-03","15":"42:03]","level":"ERROR","method":"POST","uri":"/api/v1/textdata","reqtime":"3.3160150011196476","foobar":"XfPJaFfE"}
```

You can send same set of events many times to check query behavior.

### Replay events with time

Replay events in the file, trying to preserve interval of each events. (Resolution is one second.)

```
norikra-helper event replay_with_time <target> <file>
```

Default file format is "time<TAB>log", but you can specify time from json key (`--time-key` option) and also specify `--time-format`.

```
2013/05/14 17:57:59<TAB>{"id":"0000","level":"DEBUG","method":"POST","uri":"/api/v1/people","reqtime":"3.053540515830725","foobar":"dNjtvYKx"}
2013/05/14 17:58:59<TAB>"id":"0001","level":"WARN","method":"GET","uri":"/api/v1/people","reqtime":"1.4360158435718304","foobar":"bMNxUyrL"}
2013/05/14 18:02:59<TAB>{"id":"0002","level":"INFO","method":"POST","uri":"/api/v1/people","reqtime":"0.5269335558815027","foobar":"ZqZfpVas"}
2013/05/14 18:05:59<TAB>{"id":"0003","level":"ERROR","method":"GET","uri":"/api/v1/textdata","reqtime":"2.3612488783081855","foobar":"ttoNGbj5"}
```

In this example, norikra-helper sends first event, then sleep for 1 minute, then send second event, sleep 4 minutes,.. and so on.

### See events in the target

See incoming events of specified target. 

```
norikra-helper target see <target>
```

Example:

```
% norikra-helper target see teststream
Registering query:SELECT nullable(id),nullable(time),nullable(level),nullable(method),nullable(uri),nullable(reqtime),nullable(foobar) FROM teststream
Registered query: norikra-tmp-23611_1449128094
{"time":"[2015-12-03","foobar":"uznkn7Lk","method":"PUT","level":"WARN","reqtime":"1.8970762800818766","id":"4665","uri":"/api/v1/people"}
{"time":"[2015-12-03","foobar":"7TJenTOZ","method":"POST","level":"WARN","reqtime":"2.768922685776351","id":"4666","uri":"/api/v1/textdata"}
{"time":"[2015-12-03","foobar":"VMf8882d","method":"GET","level":"ERROR","reqtime":"1.3497245936970954","id":"4667","uri":"/api/v1/textdata"}
(output continues as long as events come in and you do not enter Ctrl-C)
```

This command has a limitation. As this command just get field information of the target from Norikra and then select all fields, it cannot see fields Norikra doesn't know (e.g. Inside Hash or Array fields). 

### Clean-up queries

```
norikra-helper query cleanup [-m N] [-r]
```

If you use `query test` or `target see`, temporal query will be registerd to Norikra. This query should be removed when you stop the command, but sometimes (e.g. This program was killed, TCP session was closed, etc..) not. `query cleanup` command is useful to remove such queries. Queries older than N (Default: 30) minutes ago, will be removed by this command. Default behaviour of this command is dry-run, so if you really want to remove those queries, specify `-r` option.

## Author

Hironori Ogibayashi

