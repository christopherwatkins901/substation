package sqs

import (
	"fmt"
	"os"
	"strconv"
	"strings"

	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/sqs"
	"github.com/aws/aws-sdk-go/service/sqs/sqsiface"
	"github.com/aws/aws-xray-sdk-go/xray"
	"github.com/google/uuid"
)

// New creates a new session for SQS
func New() *sqs.SQS {
	conf := aws.NewConfig()

	// provides forward compatibility for the Go SDK to support env var configuration settings
	// https://github.com/aws/aws-sdk-go/issues/4207
	max, found := os.LookupEnv("AWS_MAX_ATTEMPTS")
	if found {
		m, err := strconv.Atoi(max)
		if err != nil {
			panic(err)
		}

		conf = conf.WithMaxRetries(m)
	}

	c := sqs.New(
		session.Must(session.NewSession()),
		conf,
	)

	if _, ok := os.LookupEnv("AWS_XRAY_DAEMON_ADDRESS"); ok {
		xray.AWS(c.Client)
	}

	return c
}

// API wraps a Kinesis Firehose client interface
type API struct {
	Client sqsiface.SQSAPI
}

// IsEnabled checks whether a new client has been set
func (a *API) IsEnabled() bool {
	return a.Client != nil
}

// Setup creates a Kinesis Firehose client
func (a *API) Setup() {
	a.Client = New()
}

// SendMessage is a convenience wrapper for sending a message to an SQS queue.
func (a *API) SendMessage(ctx aws.Context, queue string, data []byte) (*sqs.SendMessageOutput, error) {
	mgid := uuid.New().String()

	url, err := a.Client.GetQueueUrlWithContext(
		ctx,
		&sqs.GetQueueUrlInput{
			QueueName: aws.String(queue),
		})
	if err != nil {
		return nil, fmt.Errorf("sendmessagebatch queue %s: %v", queue, err)
	}

	msg := &sqs.SendMessageInput{
		MessageBody: aws.String(string(data)),
		QueueUrl:    url.QueueUrl,
	}

	if strings.HasSuffix(queue, ".fifo") {
		msg.MessageGroupId = aws.String(mgid)
	}

	resp, err := a.Client.SendMessageWithContext(ctx, msg)
	if err != nil {
		return nil, fmt.Errorf("sendmessage queue %s: %v", queue, err)
	}

	return resp, nil
}

// SendMessageBatch is a convenience wrapper for sending multiple messages to an SQS queue. This function becomes recursive for any messages that failed the SendMessage operation.
func (a *API) SendMessageBatch(ctx aws.Context, queue string, data [][]byte) (*sqs.SendMessageBatchOutput, error) {
	mgid := uuid.New().String()

	var messages []*sqs.SendMessageBatchRequestEntry
	for idx, d := range data {
		entry := &sqs.SendMessageBatchRequestEntry{
			Id:          aws.String(strconv.Itoa(idx)),
			MessageBody: aws.String(string(d)),
		}

		if strings.HasSuffix(queue, ".fifo") {
			entry.MessageGroupId = aws.String(mgid)
		}

		messages = append(messages, entry)
	}

	url, err := a.Client.GetQueueUrlWithContext(
		ctx,
		&sqs.GetQueueUrlInput{
			QueueName: aws.String(queue),
		})
	if err != nil {
		return nil, fmt.Errorf("sendmessagebatch queue %s: %v", queue, err)
	}

	resp, err := a.Client.SendMessageBatchWithContext(
		ctx,
		// TODO(v1.0.0): add ARN support
		&sqs.SendMessageBatchInput{
			Entries:  messages,
			QueueUrl: url.QueueUrl,
		},
	)

	// if a message fails, then the message ID is used to select the
	// original data that was in the message. this data is put in a
	// new slice and recursively input into the function.
	if resp.Failed != nil {
		var retry [][]byte
		for _, r := range resp.Failed {
			idx, err := strconv.Atoi(aws.StringValue(r.Id))
			if err != nil {
				return nil, fmt.Errorf("sendmessagebatch queue %s: %v", queue, err)
			}

			retry = append(retry, data[idx])
		}

		if len(retry) > 0 {
			return a.SendMessageBatch(ctx, queue, retry)
		}
	}

	if err != nil {
		return nil, fmt.Errorf("sendmessagebatch queue %s: %v", queue, err)
	}

	return resp, nil
}
