package main

import (
	"net"
	"sync"

	"github.com/concourse/atc/atccmd"
	"github.com/concourse/tsa/tsacmd"
	"github.com/hashicorp/go-multierror"
)

type WebCommand struct {
	atccmd.ATCCommand

	TSA struct {
		HostKeyPath        tsacmd.FileFlag `long:"host-key"               required:"true" description:"Key to use for the TSA's ssh server."`
		AuthorizedKeysPath tsacmd.FileFlag `long:"authorized-keys" required:"true" description:"Path to a file containing public keys to authorize for SSH access."`
	} `group:"TSA Configuration" namespace:"tsa"`
}

func (cmd *WebCommand) Execute(args []string) error {
	tsa := &tsacmd.TSACommand{
		HostKeyPath:        cmd.TSA.HostKeyPath,
		AuthorizedKeysPath: cmd.TSA.AuthorizedKeysPath,
	}

	cmd.populateTSAFlagsFromATCFlags(tsa)

	errs := make(chan error, 2)

	wg := new(sync.WaitGroup)

	wg.Add(1)
	go func() {
		defer wg.Done()
		errs <- cmd.ATCCommand.Execute(args)
	}()

	wg.Add(1)
	go func() {
		defer wg.Done()
		errs <- tsa.Execute(nil)
	}()

	wg.Wait()

	var allErrors error

	for i := 0; i < 2; i++ {
		err := <-errs
		if err != nil {
			allErrors = multierror.Append(allErrors, err)
		}
	}

	return allErrors
}

func (cmd *WebCommand) populateTSAFlagsFromATCFlags(tsa *tsacmd.TSACommand) error {
	// TODO: flag types package plz
	err := tsa.ATCURL.UnmarshalFlag(cmd.ATCCommand.PeerURL.String())
	if err != nil {
		return err
	}

	tsa.SessionSigningKeyPath = tsacmd.FileFlag(cmd.ATCCommand.SessionSigningKey)

	host, _, err := net.SplitHostPort(cmd.ATCCommand.PeerURL.URL().Host)
	if err != nil {
		return err
	}

	tsa.PeerIP = host

	tsa.Metrics.YellerAPIKey = cmd.ATCCommand.Metrics.YellerAPIKey
	tsa.Metrics.YellerEnvironment = cmd.ATCCommand.Metrics.YellerEnvironment

	return nil
}
