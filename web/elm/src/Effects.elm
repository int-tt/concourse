port module Effects exposing
    ( Callback(..)
    , Effect(..)
    , LayoutDispatch(..)
    , ScrollDirection(..)
    , SubpageDispatch(..)
    , renderPipeline
    , runEffect
    , setTitle
    )

import Concourse
import Concourse.Build
import Concourse.BuildPlan
import Concourse.BuildPrep
import Concourse.BuildResources
import Concourse.BuildStatus
import Concourse.Info
import Concourse.Job
import Concourse.Pagination exposing (Page, Paginated)
import Concourse.Pipeline
import Concourse.PipelineStatus
import Concourse.Resource
import Concourse.User
import Dashboard.APIData
import Dashboard.Group
import Dashboard.Models
import Dom
import Favicon
import Http
import Json.Encode
import LoginRedirect
import Navigation
import Process
import QueryString
import RemoteData
import Resource.Models exposing (VersionToggleAction(..))
import Scroll
import Task
import Time exposing (Time)
import Window


port setTitle : String -> Cmd msg


port renderPipeline : ( Json.Encode.Value, Json.Encode.Value ) -> Cmd msg


port pinTeamNames : Dashboard.Group.StickyHeaderConfig -> Cmd msg


port tooltip : ( String, String ) -> Cmd msg


port tooltipHd : ( String, String ) -> Cmd msg


port resetPipelineFocus : () -> Cmd msg


port loadToken : () -> Cmd msg


port saveToken : String -> Cmd msg


type LayoutDispatch
    = TopBar Int
    | SubPage Int SubpageDispatch
    | Layout


type SubpageDispatch
    = Normal
    | Autoscroll


type Effect
    = FetchJob Concourse.JobIdentifier
    | FetchJobs Concourse.PipelineIdentifier
    | FetchJobBuilds Concourse.JobIdentifier (Maybe Page)
    | FetchResource Concourse.ResourceIdentifier
    | FetchVersionedResources Concourse.ResourceIdentifier (Maybe Page)
    | FetchResources Concourse.PipelineIdentifier
    | FetchBuildResources Concourse.BuildId
    | FetchPipeline Concourse.PipelineIdentifier
    | FetchVersion
    | FetchInputTo Concourse.VersionedResourceIdentifier
    | FetchOutputOf Concourse.VersionedResourceIdentifier
    | FetchData
    | FetchUser
    | FetchBuild Time Int Int
    | FetchJobBuild Int Concourse.JobBuildIdentifier
    | FetchBuildJobDetails Concourse.JobIdentifier
    | FetchBuildHistory Concourse.JobIdentifier (Maybe Page)
    | FetchBuildPrep Time Int Int
    | FetchBuildPlan Int
    | FetchBuildPlanAndResources Int
    | FocusSearchInput
    | GetCurrentTime
    | DoTriggerBuild Concourse.JobIdentifier String
    | DoAbortBuild Int Concourse.CSRFToken
    | PauseJob Concourse.JobIdentifier String
    | UnpauseJob Concourse.JobIdentifier String
    | ResetPipelineFocus
    | RenderPipeline Json.Encode.Value Json.Encode.Value
    | RedirectToLogin
    | NavigateTo String
    | SetTitle String
    | ModifyUrl String
    | DoPinVersion Concourse.VersionedResourceIdentifier Concourse.CSRFToken
    | DoUnpinVersion Concourse.ResourceIdentifier Concourse.CSRFToken
    | DoToggleVersion VersionToggleAction Concourse.VersionedResourceIdentifier Concourse.CSRFToken
    | DoCheck Concourse.ResourceIdentifier Concourse.CSRFToken
    | SendTokenToFly String Int
    | SendTogglePipelineRequest { pipeline : Dashboard.Models.Pipeline, csrfToken : Concourse.CSRFToken }
    | ShowTooltip ( String, String )
    | ShowTooltipHd ( String, String )
    | SendOrderPipelinesRequest String (List Dashboard.Models.Pipeline) Concourse.CSRFToken
    | SendLogOutRequest
    | GetScreenSize
    | PinTeamNames Dashboard.Group.StickyHeaderConfig
    | Scroll ScrollDirection
    | ResetFavicon
    | SetFavIcon Concourse.BuildStatus
    | SaveToken String
    | LoadToken


type ScrollDirection
    = ToWindowTop
    | Down
    | Up
    | ToBottomOf String
    | ToWindowBottom
    | Builds Float
    | ToCurrentBuild


type Callback
    = EmptyCallback
    | GotCurrentTime Time
    | BuildTriggered (Result Http.Error Concourse.Build)
    | JobBuildsFetched (Result Http.Error (Paginated Concourse.Build))
    | JobFetched (Result Http.Error Concourse.Job)
    | JobsFetched (Result Http.Error Json.Encode.Value)
    | PipelineFetched (Result Http.Error Concourse.Pipeline)
    | UserFetched (Result Http.Error Concourse.User)
    | ResourcesFetched (Result Http.Error Json.Encode.Value)
    | BuildResourcesFetched Int (Result Http.Error Concourse.BuildResources)
    | ResourceFetched (Result Http.Error Concourse.Resource)
    | VersionedResourcesFetched (Maybe Page) (Result Http.Error (Paginated Concourse.VersionedResource))
    | VersionFetched (Result Http.Error String)
    | PausedToggled (Result Http.Error ())
    | InputToFetched Int (Result Http.Error (List Concourse.Build))
    | OutputOfFetched Int (Result Http.Error (List Concourse.Build))
    | VersionPinned (Result Http.Error ())
    | VersionUnpinned (Result Http.Error ())
    | VersionToggled VersionToggleAction Int (Result Http.Error ())
    | Checked (Result Http.Error ())
    | TokenSentToFly Bool
    | APIDataFetched (RemoteData.WebData ( Time.Time, Dashboard.APIData.APIData ))
    | LoggedOut (Result Http.Error ())
    | ScreenResized Window.Size
    | BuildJobDetailsFetched (Result Http.Error Concourse.Job)
    | BuildFetched Int (Result Http.Error Concourse.Build)
    | BuildPrepFetched Int (Result Http.Error Concourse.BuildPrep)
    | BuildHistoryFetched (Result Http.Error (Paginated Concourse.Build))
    | PlanAndResourcesFetched (Result Http.Error ( Concourse.BuildPlan, Concourse.BuildResources ))
    | BuildAborted (Result Http.Error ())


runEffect : Effect -> Cmd Callback
runEffect effect =
    case effect of
        FetchJob id ->
            fetchJob id

        FetchJobs id ->
            fetchJobs id

        FetchJobBuilds id page ->
            fetchJobBuilds id page

        FetchResource id ->
            fetchResource id

        FetchVersionedResources id paging ->
            fetchVersionedResources id paging

        FetchResources id ->
            fetchResources id

        FetchBuildResources id ->
            fetchBuildResources id

        FetchPipeline id ->
            fetchPipeline id

        FetchVersion ->
            fetchVersion

        FetchInputTo id ->
            fetchInputTo id

        FetchOutputOf id ->
            fetchOutputOf id

        FetchData ->
            fetchData

        GetCurrentTime ->
            Task.perform GotCurrentTime Time.now

        DoTriggerBuild id csrf ->
            triggerBuild id csrf

        PauseJob id csrf ->
            pauseJob id csrf

        UnpauseJob id csrf ->
            unpauseJob id csrf

        RedirectToLogin ->
            LoginRedirect.requestLoginRedirect ""

        NavigateTo newUrl ->
            Navigation.newUrl newUrl

        ResetPipelineFocus ->
            resetPipelineFocus ()

        RenderPipeline jobs resources ->
            renderPipeline ( jobs, resources )

        SetTitle newTitle ->
            setTitle newTitle

        DoPinVersion version csrfToken ->
            Task.attempt VersionPinned <|
                Concourse.Resource.pinVersion version csrfToken

        DoUnpinVersion id csrfToken ->
            Task.attempt VersionUnpinned <|
                Concourse.Resource.unpinVersion id csrfToken

        DoToggleVersion action id csrfToken ->
            Task.attempt (VersionToggled action id.versionID) <|
                Concourse.Resource.enableDisableVersionedResource (action == Enable) id csrfToken

        DoCheck rid csrfToken ->
            Task.attempt Checked <|
                Concourse.Resource.check rid csrfToken

        SendTokenToFly authToken flyPort ->
            sendTokenToFly authToken flyPort

        FocusSearchInput ->
            Task.attempt (always EmptyCallback) (Dom.focus "search-input-field")

        ModifyUrl url ->
            Navigation.modifyUrl url

        SendTogglePipelineRequest { pipeline, csrfToken } ->
            togglePipelinePaused { pipeline = pipeline, csrfToken = csrfToken }

        ShowTooltip ( teamName, pipelineName ) ->
            tooltip ( teamName, pipelineName )

        ShowTooltipHd ( teamName, pipelineName ) ->
            tooltipHd ( teamName, pipelineName )

        SendOrderPipelinesRequest teamName pipelines csrfToken ->
            orderPipelines teamName pipelines csrfToken

        SendLogOutRequest ->
            Task.attempt LoggedOut Concourse.User.logOut

        GetScreenSize ->
            Task.perform ScreenResized Window.size

        PinTeamNames stickyHeaderConfig ->
            pinTeamNames stickyHeaderConfig

        FetchBuild delay browsingIndex buildId ->
            fetchBuild delay browsingIndex buildId

        FetchJobBuild browsingIndex jbi ->
            fetchJobBuild browsingIndex jbi

        FetchBuildJobDetails buildJob ->
            fetchBuildJobDetails buildJob

        FetchBuildHistory job page ->
            fetchBuildHistory job page

        FetchBuildPrep delay browsingIndex buildId ->
            fetchBuildPrep delay browsingIndex buildId

        FetchBuildPlanAndResources buildId ->
            fetchBuildPlanAndResources buildId

        FetchBuildPlan buildId ->
            fetchBuildPlan buildId

        FetchUser ->
            fetchUser

        ResetFavicon ->
            resetFavicon

        SetFavIcon status ->
            setFavicon status

        DoAbortBuild buildId csrfToken ->
            abortBuild buildId csrfToken

        Scroll dir ->
            Task.perform (always EmptyCallback) (scrollInDirection dir)

        SaveToken tokenValue ->
            saveToken tokenValue

        LoadToken ->
            loadToken ()


fetchJobBuilds : Concourse.JobIdentifier -> Maybe Concourse.Pagination.Page -> Cmd Callback
fetchJobBuilds jobIdentifier page =
    Task.attempt JobBuildsFetched <|
        Concourse.Build.fetchJobBuilds jobIdentifier page


fetchJob : Concourse.JobIdentifier -> Cmd Callback
fetchJob jobIdentifier =
    Task.attempt JobFetched <|
        Concourse.Job.fetchJob jobIdentifier


fetchResource : Concourse.ResourceIdentifier -> Cmd Callback
fetchResource resourceIdentifier =
    Task.attempt ResourceFetched <|
        Concourse.Resource.fetchResource resourceIdentifier


fetchVersionedResources : Concourse.ResourceIdentifier -> Maybe Page -> Cmd Callback
fetchVersionedResources resourceIdentifier page =
    Task.attempt (VersionedResourcesFetched page) <|
        Concourse.Resource.fetchVersionedResources resourceIdentifier page


fetchBuildResources : Concourse.BuildId -> Cmd Callback
fetchBuildResources buildIdentifier =
    Task.attempt (BuildResourcesFetched buildIdentifier) <|
        Concourse.BuildResources.fetch buildIdentifier


fetchResources : Concourse.PipelineIdentifier -> Cmd Callback
fetchResources pid =
    Task.attempt ResourcesFetched <| Concourse.Resource.fetchResourcesRaw pid


fetchJobs : Concourse.PipelineIdentifier -> Cmd Callback
fetchJobs pid =
    Task.attempt JobsFetched <| Concourse.Job.fetchJobsRaw pid


fetchUser : Cmd Callback
fetchUser =
    Task.attempt UserFetched Concourse.User.fetchUser


fetchVersion : Cmd Callback
fetchVersion =
    Concourse.Info.fetch
        |> Task.map .version
        |> Task.attempt VersionFetched


fetchPipeline : Concourse.PipelineIdentifier -> Cmd Callback
fetchPipeline pipelineIdentifier =
    Task.attempt PipelineFetched <|
        Concourse.Pipeline.fetchPipeline pipelineIdentifier


fetchInputTo : Concourse.VersionedResourceIdentifier -> Cmd Callback
fetchInputTo versionedResourceIdentifier =
    Task.attempt (InputToFetched versionedResourceIdentifier.versionID) <|
        Concourse.Resource.fetchInputTo versionedResourceIdentifier


fetchOutputOf : Concourse.VersionedResourceIdentifier -> Cmd Callback
fetchOutputOf versionedResourceIdentifier =
    Task.attempt (OutputOfFetched versionedResourceIdentifier.versionID) <|
        Concourse.Resource.fetchOutputOf versionedResourceIdentifier


triggerBuild : Concourse.JobIdentifier -> Concourse.CSRFToken -> Cmd Callback
triggerBuild job csrfToken =
    Task.attempt BuildTriggered <|
        Concourse.Job.triggerBuild job csrfToken


pauseJob : Concourse.JobIdentifier -> Concourse.CSRFToken -> Cmd Callback
pauseJob jobIdentifier csrfToken =
    Task.attempt PausedToggled <|
        Concourse.Job.pause jobIdentifier csrfToken


unpauseJob : Concourse.JobIdentifier -> Concourse.CSRFToken -> Cmd Callback
unpauseJob jobIdentifier csrfToken =
    Task.attempt PausedToggled <|
        Concourse.Job.unpause jobIdentifier csrfToken


sendTokenToFly : String -> Int -> Cmd Callback
sendTokenToFly authToken flyPort =
    let
        queryString =
            QueryString.empty
                |> QueryString.add "token" authToken
                |> QueryString.render
    in
    Http.request
        { method = "GET"
        , headers = []
        , url = "http://127.0.0.1:" ++ toString flyPort ++ queryString
        , body = Http.emptyBody
        , expect = Http.expectStringResponse (\_ -> Ok ())
        , timeout = Nothing
        , withCredentials = False
        }
        |> Http.send (\r -> TokenSentToFly (r == Ok ()))


fetchData : Cmd Callback
fetchData =
    Dashboard.APIData.remoteData
        |> Task.map2 (,) Time.now
        |> RemoteData.asCmd
        |> Cmd.map APIDataFetched


togglePipelinePaused : { pipeline : Dashboard.Models.Pipeline, csrfToken : Concourse.CSRFToken } -> Cmd Callback
togglePipelinePaused { pipeline, csrfToken } =
    Task.attempt (always EmptyCallback) <|
        if pipeline.status == Concourse.PipelineStatus.PipelineStatusPaused then
            Concourse.Pipeline.unpause pipeline.teamName pipeline.name csrfToken

        else
            Concourse.Pipeline.pause pipeline.teamName pipeline.name csrfToken


orderPipelines : String -> List Dashboard.Models.Pipeline -> Concourse.CSRFToken -> Cmd Callback
orderPipelines teamName pipelines csrfToken =
    Task.attempt (always EmptyCallback) <|
        Concourse.Pipeline.order teamName (List.map .name pipelines) csrfToken


fetchBuildJobDetails : Concourse.JobIdentifier -> Cmd Callback
fetchBuildJobDetails buildJob =
    Task.attempt BuildJobDetailsFetched <|
        Concourse.Job.fetchJob buildJob


fetchBuild : Time -> Int -> Int -> Cmd Callback
fetchBuild delay browsingIndex buildId =
    Task.attempt (BuildFetched browsingIndex)
        (Process.sleep delay
            |> Task.andThen (always <| Concourse.Build.fetch buildId)
        )


fetchJobBuild : Int -> Concourse.JobBuildIdentifier -> Cmd Callback
fetchJobBuild browsingIndex jbi =
    Task.attempt (BuildFetched browsingIndex) <|
        Concourse.Build.fetchJobBuild jbi


fetchBuildHistory : Concourse.JobIdentifier -> Maybe Concourse.Pagination.Page -> Cmd Callback
fetchBuildHistory job page =
    Task.attempt BuildHistoryFetched <|
        Concourse.Build.fetchJobBuilds job page


fetchBuildPrep : Time -> Int -> Int -> Cmd Callback
fetchBuildPrep delay browsingIndex buildId =
    Process.sleep delay
        |> Task.andThen (always <| Concourse.BuildPrep.fetch buildId)
        |> Task.attempt (BuildPrepFetched browsingIndex)


fetchBuildPlanAndResources : Int -> Cmd Callback
fetchBuildPlanAndResources buildId =
    Task.attempt PlanAndResourcesFetched <|
        Task.map2 (,) (Concourse.BuildPlan.fetch buildId) (Concourse.BuildResources.fetch buildId)


fetchBuildPlan : Int -> Cmd Callback
fetchBuildPlan buildId =
    Task.attempt PlanAndResourcesFetched <|
        Task.map (flip (,) Concourse.BuildResources.empty) (Concourse.BuildPlan.fetch buildId)


resetFavicon : Cmd Callback
resetFavicon =
    Task.perform (always EmptyCallback) <|
        Favicon.set "/public/images/favicon.png"


setFavicon : Concourse.BuildStatus -> Cmd Callback
setFavicon status =
    Task.perform (always EmptyCallback) <|
        Favicon.set ("/public/images/favicon-" ++ Concourse.BuildStatus.show status ++ ".png")


abortBuild : Int -> Concourse.CSRFToken -> Cmd Callback
abortBuild buildId csrfToken =
    Concourse.Build.abort buildId csrfToken
        |> Task.attempt BuildAborted


scrollInDirection : ScrollDirection -> Task.Task x ()
scrollInDirection dir =
    case dir of
        ToWindowTop ->
            Scroll.toWindowTop

        Down ->
            Scroll.scrollDown

        Up ->
            Scroll.scrollUp

        ToBottomOf ele ->
            Scroll.toBottom ele

        ToWindowBottom ->
            Scroll.toWindowBottom

        Builds delta ->
            Scroll.scroll "builds" delta

        ToCurrentBuild ->
            Scroll.scrollIntoView "#builds .current"
