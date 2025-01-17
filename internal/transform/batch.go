package transform

import (
	"context"
	"sync"
	"time"

	"github.com/brexhq/substation/config"
	"github.com/brexhq/substation/internal/metrics"
	"github.com/brexhq/substation/process"
)

// batch transforms data by applying a series of processors to a slice of
// encapsulated data.
//
// Data processing is iterative and each processor is enabled through conditions.
type tformBatch struct {
	Processors []config.Config `json:"processors"`

	batchers []process.Batcher
}

func newTformBatch(ctx context.Context, cfg config.Config) (t tformBatch, err error) {
	if err = config.Decode(cfg.Settings, &t); err != nil {
		return tformBatch{}, err
	}

	t.batchers, err = process.NewBatchers(ctx, t.Processors...)
	if err != nil {
		return tformBatch{}, err
	}

	return t, nil
}

// Transform processes a channel of encapsulated data with the transform.
func (t tformBatch) Transform(ctx context.Context, wg *sync.WaitGroup, in, out *config.Channel) error {
	/*
		closing processors in an anonymous goroutine blocked by the WaitGroup from the calling application
		ensures that all processors across the entire app close after all data transformation is finished.
		As of now this is the only way to prevent premature closing of processors and avoid panics that can
		occur if processors running inside one transform attempt to access resources closed by processors
		running inside of a different t.
	*/
	go func() {
		wg.Wait()
		//nolint: errcheck // errors are ignored in case closing fails in a single processor
		process.CloseBatchers(ctx, t.batchers...)
	}()

	var received int
	// read encapsulated data from the input channel into a batch
	batch := make([]config.Capsule, 0, 10)
	for capsule := range in.C {
		select {
		case <-ctx.Done():
			return ctx.Err()
		default:
			batch = append(batch, capsule)
			received++

			// sleep load balances data across transform goroutines, otherwise a single goroutine may receive more capsules than others
			// this creates 1 second of delay for every 100,000 capsules put into the input channel
			time.Sleep(time.Duration(10) * time.Microsecond)
		}
	}

	// iteratively process the batch of encapsulated data
	batch, err := process.Batch(ctx, batch, t.batchers...)
	if err != nil {
		return err
	}

	var sent int
	// write the processed, encapsulated data to the output channel
	for _, capsule := range batch {
		select {
		case <-ctx.Done():
			return ctx.Err()
		default:
			out.Send(capsule)
			sent++
		}
	}

	_ = metrics.Generate(ctx, metrics.Data{
		Name:  "CapsulesReceived",
		Value: received,
	})

	_ = metrics.Generate(ctx, metrics.Data{
		Name:  "CapsulesSent",
		Value: sent,
	})

	return nil
}
