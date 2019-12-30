module Main exposing (main)

import Api
import Browser
import Dict
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick, onInput, onSubmit)
import Http
import Json.Decode as Decode exposing (Decoder, Value)
import Json.Encode as Encode
import Maybe
import Session exposing (Session)
import Task
import Types exposing (ContactError(..), Model, Msg(..), Response(..))



-- STARTUP


main =
    Browser.element
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }


init : () -> ( Model, Cmd Msg )
init _ =
    ( Model "" "" "" "Words of Praise" "" "" "" Nothing NotSent True, Api.getCaptcha Nothing )



-- UPDATE


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        RequestCaptcha ->
            ( model
            , Api.getCaptcha model.session
            )

        GotCaptchaImage (Ok ( image, session )) ->
            ( { model | captcha = image, session = session }
            , Cmd.none
            )

        GotCaptchaImage (Err err) ->
            let
                ( response, formEnabled ) =
                    case err of
                        Http.NetworkError ->
                            ( "Contact system is currently offline. Please try again later.", False )

                        Http.BadStatus 500 ->
                            ( "Cannot generate a captcha image. Please try again later.", False )

                        Http.BadStatus 503 ->
                            ( "Please refresh a little slower, we have limited your requests.", True )

                        _ ->
                            ( "Something is currently wong with the contact system. The administrator has been notified. Please try again later.", False )
            in
            ( { model | response = Bad response, formEnabled = formEnabled }
            , Cmd.none
            )

        SendContact ->
            ( model
            , Api.sendContactRequest model
            )

        ConfirmSendContact (Ok _) ->
            ( { model | response = Good "Your message has been recieved! We'll get back to you as soon as we can.", name = "", email = "", message = "", challenge = "", formEnabled = False }, Api.getCaptcha Nothing )

        ConfirmSendContact (Err err) ->
            let
                ( response, cmd, formEnabled ) =
                    case err of
                        InvalidChallenge ->
                            ( "The captcha challenge value you entered was incorrect. Please try again.", Cmd.none, True )

                        SessionExpired ->
                            ( "Your session expired. Please type in the new value of the captcha and resend your message.", Api.getCaptcha Nothing, True )

                        NoSessionHeader ->
                            ( "Your browser didn't send me a session value, I can't confirm you're not a bot. Please try again with this new captcha.", Api.getCaptcha Nothing, True )

                        _ ->
                            ( "An error occured processing your message. Please try again or a little later. The administrator has been notified of this failure so will hopefully fix this issue soon.", Api.getCaptcha Nothing, True )
            in
            ( { model | response = Bad response, challenge = "", formEnabled = formEnabled }, cmd )

        UpdateName name ->
            ( { model | name = name }, Cmd.none )

        UpdateEmail email ->
            ( { model | email = email }, Cmd.none )

        UpdateWebsite url ->
            ( { model | website = url }, Cmd.none )

        UpdateSubject subject ->
            ( { model | subject = subject }, Cmd.none )

        UpdateMessage message ->
            ( { model | message = message }, Cmd.none )

        UpdateChallenge challenge ->
            ( { model | challenge = challenge }, Cmd.none )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none



-- VIEW


view : Model -> Html Msg
view model =
    let
        ( responseClass, responseText ) =
            case model.response of
                Good response ->
                    ( "green", response )

                Bad error ->
                    ( "red", error )

                NotSent ->
                    ( "", "" )
    in
    if model.formEnabled then
        div
            [ id "contact" ]
            [ Html.form [ method "post", onSubmit SendContact ]
                [ Html.fieldset []
                    [ Html.legend [] [ text "Contact Details" ]
                    , div [ class "cell" ]
                        [ Html.label [ for "name" ] [ text "Your Name" ]
                        , input [ required True, placeholder "Enter your name", type_ "text", name "name", value model.name, onInput UpdateName ] []
                        ]
                    , div [ class "cell" ]
                        [ Html.label [ for "email" ] [ text "Your Email" ]
                        , input [ required True, placeholder "Enter your email address", type_ "email", name "email", value model.email, onInput UpdateEmail ] []
                        ]
                    , div [ class "cell" ]
                        [ Html.label [ for "website" ] [ text "Website (optional)" ]
                        , input [ placeholder "Enter your URL", type_ "url", name "website", value model.website, onInput UpdateWebsite ] []
                        ]
                    ]
                , Html.fieldset []
                    [ legend [] [ text "Your Message" ]
                    , div [ class "cell" ]
                        [ label [ for "subject" ] [ text "Subject" ]
                        , select [ required True, name "subject", onInput UpdateSubject ] <| subjectOptions model.subject
                        ]
                    , div [ class "cell" ]
                        [ label [ for "message" ] [ text "Message" ]
                        , textarea [ required True, spellcheck True, rows 4, name "message", value model.message, onInput UpdateMessage ] []
                        ]
                    ]
                , Html.fieldset []
                    [ legend [] [ text "Pass the Turing Test" ]
                    , div [ class "captcha" ]
                        [ img [ class "img-verify", src model.captcha ] []
                        , div [ class "control" ]
                            [ button [ class "click", onClick RequestCaptcha ] [ text "Refresh" ]
                            , input [ class "verify", autocomplete False, required True, placeholder "Copy the code", type_ "text", name "verify", title "This confirms you are a human user or strong AI and not a spam-bot.", value model.challenge, onInput UpdateChallenge ] []
                            ]
                        ]
                    ]
                , div []
                    [ input [ type_ "submit", class "click submit", Html.Attributes.value "Energize" ] []
                    , div [ id "response", class responseClass ] [ text responseText ]
                    ]
                ]
            ]

    else
        let
            alternate =
                if responseClass == "green" then
                    text ""

                else
                    div [ class "alternate" ]
                        [ text "Alternatively, contact Tim directly on "
                        , a [ href "https://keybase.io/Libbum" ] [ text "Keybase" ]
                        , text " or "
                        , a [ href "https://telegram.me/Libbum" ] [ text "Telegram" ]
                        , text "."
                        ]
        in
        div [ id "response", class responseClass ]
            [ text responseText
            , alternate
            ]


subjectOptions : String -> List (Html msg)
subjectOptions subjectModel =
    [ "Words of Praise", "WTF", "Tech Question", "Offer Expertise" ]
        |> List.map
            (\subjectOption ->
                option [ value subjectOption, selected (subjectOption == subjectModel) ] [ text subjectOption ]
            )
