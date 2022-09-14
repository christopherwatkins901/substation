package process

import (
	"bytes"
	"context"
	"testing"

	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/request"
	"github.com/aws/aws-sdk-go/service/dynamodb"
	"github.com/aws/aws-sdk-go/service/dynamodb/dynamodbiface"
	"github.com/brexhq/substation/config"
	ddb "github.com/brexhq/substation/internal/aws/dynamodb"
)

type mockedQuery struct {
	dynamodbiface.DynamoDBAPI
	Resp dynamodb.QueryOutput
}

func (m mockedQuery) QueryWithContext(ctx aws.Context, input *dynamodb.QueryInput, opts ...request.Option) (*dynamodb.QueryOutput, error) {
	return &m.Resp, nil
}

var dynamodbTests = []struct {
	name     string
	proc     DynamoDB
	test     []byte
	expected []byte
	err      error
	api      ddb.API
}{
	{
		"JSON",
		DynamoDB{
			Options: DynamoDBOptions{
				Table:                  "fooer",
				KeyConditionExpression: "barre",
			},
			InputKey:  "foo",
			OutputKey: "foo",
		},
		[]byte(`{"foo":{"PK":"bar"}}`),
		[]byte(`{"foo":[{"baz":"qux"}]}`),
		nil,
		ddb.API{
			Client: mockedQuery{
				Resp: dynamodb.QueryOutput{
					Items: []map[string]*dynamodb.AttributeValue{
						{
							"baz": {
								S: aws.String("qux"),
							},
						},
					},
				},
			},
		},
	},
}

func TestDynamoDB(t *testing.T) {
	ctx := context.TODO()
	cap := config.NewCapsule()

	for _, test := range dynamodbTests {
		dynamodbAPI = test.api
		cap.SetData(test.test)

		result, err := test.proc.Apply(ctx, cap)
		if err != nil {
			t.Log(err)
			t.Fail()
		}

		if !bytes.Equal(result.GetData(), test.expected) {
			t.Logf("expected %s, got %s", test.expected, result.GetData())
			t.Fail()
		}
	}
}

func benchmarkDynamoDB(b *testing.B, applicator DynamoDB, test config.Capsule) {
	ctx := context.TODO()
	for i := 0; i < b.N; i++ {
		applicator.Apply(ctx, test)
	}
}

func BenchmarkDynamoDB(b *testing.B) {
	cap := config.NewCapsule()
	for _, test := range dynamodbTests {
		b.Run(string(test.name),
			func(b *testing.B) {
				dynamodbAPI = test.api
				cap.SetData(test.test)
				benchmarkDynamoDB(b, test.proc, cap)
			},
		)
	}
}