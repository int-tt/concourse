package exec

import (
	"context"
	"fmt"

	"github.com/concourse/concourse/atc/runtime"

	"code.cloudfoundry.org/lager"
	"code.cloudfoundry.org/lager/lagerctx"
	"github.com/concourse/concourse/atc"
	"github.com/concourse/concourse/atc/db"
	"github.com/concourse/concourse/atc/exec/build"
	"github.com/concourse/concourse/atc/worker"
)

type ArtifactVolumeNotFoundError struct {
	ArtifactName string
}

func (e ArtifactVolumeNotFoundError) Error() string {
	return fmt.Sprintf("volume for worker artifact '%s' not found", e.ArtifactName)
}

type ArtifactInputStep struct {
	plan         atc.Plan
	build        db.Build
	workerClient worker.Client
	delegate     BuildStepDelegate
	succeeded    bool
}

func NewArtifactInputStep(plan atc.Plan, build db.Build, workerClient worker.Client, delegate BuildStepDelegate) Step {
	return &ArtifactInputStep{
		plan:         plan,
		build:        build,
		workerClient: workerClient,
		delegate:     delegate,
	}
}

func (step *ArtifactInputStep) Run(ctx context.Context, state RunState) error {
	logger := lagerctx.FromContext(ctx).WithData(lager.Data{
		"plan-id": step.plan.ID,
	})

	buildArtifact, err := step.build.Artifact(step.plan.ArtifactInput.ArtifactID)
	if err != nil {
		return err
	}

	createdVolume, found, err := buildArtifact.Volume(step.build.TeamID())
	if err != nil {
		return err
	}

	if !found {
		return ArtifactVolumeNotFoundError{buildArtifact.Name()}
	}

	art := runtime.TaskArtifact{
		VolumeHandle: createdVolume.Handle(),
	}

	//volume, found, err := buildArtifact.Volume(step.build.TeamID())
	//if err != nil {
	//	return err
	//}
	//
	//if !found {
	//	return ArtifactVolumeNotFoundError{buildArtifact.ArtifactName()}
	//}
	//
	//workerVolume, found, err := step.workerClient.FindVolume(logger, volume.TeamID(), volume.Handle())
	//if err != nil {
	//	return err
	//}
	//
	//if !found {
	//	return ArtifactVolumeNotFoundError{buildArtifact.ArtifactName()}
	//}

	logger.Info("register-artifact-source", lager.Data{
		"artifact_id": buildArtifact.ID(),
		"handle":      art.ID(),
	})

	state.Artifacts().RegisterArtifact(build.ArtifactName(step.plan.ArtifactInput.Name), &art)

	step.succeeded = true

	return nil
}

func (step *ArtifactInputStep) Succeeded() bool {
	return step.succeeded
}
