package main

import (
	"context"
	"fmt"
	"os"
	"sync"

	"github.com/brexhq/substation/cmd"
	"github.com/brexhq/substation/config"
	"github.com/brexhq/substation/internal/service"

	"golang.org/x/sync/errgroup"
)

func main() {
	sub := cmd.New()

	f, err := os.Open("./config.json")
	if err != nil {
		panic(err)
	}
	defer f.Close()

	if err := sub.SetConfig(f); err != nil {
		panic(err)
	}

	// maintains app state
	group, ctx := errgroup.WithContext(context.TODO())

	// create the gRPC server
	server := service.Server{}
	server.Setup()

	// deferring guarantees that the gRPC server will shutdown
	defer server.Stop()

	// create the server API for the Sink service and register it with the server
	srv := &service.Sink{}
	server.RegisterSink(srv)

	// gRPC server runs in a goroutine to prevent blocking main
	group.Go(func() error {
		return server.Start("localhost:50051")
	})

	// sink goroutine
	var sinkWg sync.WaitGroup
	sinkWg.Add(1)
	group.Go(func() error {
		return sub.Sink(ctx, &sinkWg)
	})

	// transform goroutine
	var transformWg sync.WaitGroup
	transformWg.Add(1)
	group.Go(func() error {
		return sub.Transform(ctx, &transformWg)
	})

	// ingest goroutine
	group.Go(func() error {
		data := [][]byte{
			[]byte(`{"foo":"bar"}`),
			[]byte(`{"baz":"qux"}`),
			[]byte(`{"quux":"corge"}`),
		}

		cap := config.NewCapsule()

		fmt.Println("sending capsules into Substation ...")
		for _, d := range data {
			fmt.Println(string(d))
			cap.SetData(d)
			sub.Send(cap)
		}

		sub.WaitTransform(&transformWg)
		sub.WaitSink(&sinkWg)

		return nil
	})

	// block until all Substation processing is complete
	if err := sub.Block(ctx, group); err != nil {
		panic(err)
	}

	// block until the gRPC server has received all capsules and the stream is closed
	srv.Block()

	fmt.Println("returning capsules sent from gRPC sink ...")
	for _, cap := range srv.Capsules {
		fmt.Println(string(cap.Data()))
	}
}
