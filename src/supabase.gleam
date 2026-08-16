import gleam/dynamic/decode
import gleam/http
import gleam/http/request
import gleam/result
import lustre/effect
import rsvp

const supabase_url = "https://kcyojklgaqulgbhgunei.supabase.co"

const supabase_key = "sb_publishable_WsNdxtxHpblMmAeI62qCUg_PO3VOuUx"

pub fn get_json(
  path: String,
  decoder: decode.Decoder(a),
  message: fn(Result(a, rsvp.Error(String))) -> msg,
) -> effect.Effect(msg) {
  let assert Ok(req) = request.to(supabase_url <> path)

  let req =
    req
    |> request.set_header("apikey", supabase_key)
    |> request.set_header("Authorization", "Bearer " <> supabase_key)

  let handler = rsvp.expect_json(decoder, message)

  rsvp.send(req, handler)
}

pub fn post_json(
  path: String,
  body: String,
  decoder: decode.Decoder(a),
  message: fn(Result(a, rsvp.Error(String))) -> msg,
) -> effect.Effect(msg) {
  let assert Ok(req) = request.to(supabase_url <> path)

  let req =
    req
    |> request.set_method(http.Post)
    |> request.set_header("apikey", supabase_key)
    |> request.set_header("Authorization", "Bearer " <> supabase_key)
    |> request.set_header("Content-Type", "application/json")
    |> request.set_body(body)

  let handler = rsvp.expect_json(decoder, message)

  rsvp.send(req, handler)
}

pub fn post_json_with_auth(
  path: String,
  jwt: String,
  body: String,
  decoder: decode.Decoder(a),
  message: fn(Result(a, rsvp.Error(String))) -> msg,
) -> effect.Effect(msg) {
  let assert Ok(req) = request.to(supabase_url <> path)

  let req =
    req
    |> request.set_method(http.Post)
    |> request.set_header("apikey", supabase_key)
    |> request.set_header("Authorization", "Bearer " <> jwt)
    |> request.set_header("Content-Type", "application/json")
    |> request.set_body(body)

  let handler = rsvp.expect_json(decoder, message)

  rsvp.send(req, handler)
}

pub fn post_with_auth(
  path: String,
  jwt: String,
  body: String,
  message: fn(Result(Nil, rsvp.Error(String))) -> msg,
) -> effect.Effect(msg) {
  let assert Ok(req) = request.to(supabase_url <> path)

  let req =
    req
    |> request.set_method(http.Post)
    |> request.set_header("apikey", supabase_key)
    |> request.set_header("Authorization", "Bearer " <> jwt)
    |> request.set_header("Content-Type", "application/json")
    |> request.set_body(body)

  let handler =
    rsvp.expect_ok_response(fn(response_result) {
      message(result.map(response_result, fn(_response) { Nil }))
    })

  rsvp.send(req, handler)
}
