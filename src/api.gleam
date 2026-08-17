import gleam/dynamic/decode
import gleam/json
import gleam/option.{type Option}
import lustre/effect
import rsvp
import supabase

import types.{type AdminFamily, type AdminRow, type Candidate, type ResultRow}

// -----------------------------------------------------------------------------
// Family ballot
// -----------------------------------------------------------------------------

pub type FamilyBallotRow {
  FamilyBallotRow(
    swimmer_id: String,
    swimmer_name: String,
    has_voted: Bool,
    voting_open: Bool,
    voted_for_name: Option(String),
  )
}

fn family_ballot_row_decoder() -> decode.Decoder(FamilyBallotRow) {
  use swimmer_id <- decode.field("swimmer_id", decode.string)
  use swimmer_name <- decode.field("swimmer_name", decode.string)
  use has_voted <- decode.field("has_voted", decode.bool)
  use voting_open <- decode.field("voting_open", decode.bool)
  use voted_for_name <- decode.field(
    "voted_for_name",
    decode.optional(decode.string),
  )
  decode.success(FamilyBallotRow(
    swimmer_id:,
    swimmer_name:,
    has_voted:,
    voting_open:,
    voted_for_name:,
  ))
}

pub fn family_ballot_decoder() -> decode.Decoder(List(FamilyBallotRow)) {
  decode.list(family_ballot_row_decoder())
}

pub fn get_family_ballot(
  token: String,
  message: fn(Result(List(FamilyBallotRow), rsvp.Error(String))) -> msg,
) -> effect.Effect(msg) {
  let body = json.object([#("token", json.string(token))])

  supabase.post_json(
    "/rest/v1/rpc/get_family_ballot",
    json.to_string(body),
    family_ballot_decoder(),
    message,
  )
}

// -----------------------------------------------------------------------------
// Candidate roster
// -----------------------------------------------------------------------------

pub fn get_roster(
  message: fn(Result(List(Candidate), rsvp.Error(String))) -> msg,
) -> effect.Effect(msg) {
  supabase.get_json(
    "/rest/v1/swimmer_roster?select=id,name",
    roster_decoder(),
    message,
  )
}

pub fn roster_decoder() -> decode.Decoder(List(Candidate)) {
  types.candidate_list_decoder()
}

// -----------------------------------------------------------------------------
// Cast vote
// -----------------------------------------------------------------------------

pub fn cast_vote(
  token: String,
  voter_swimmer_id: String,
  candidate_id: String,
  message: fn(Result(String, rsvp.Error(String))) -> msg,
) -> effect.Effect(msg) {
  let body =
    json.object([
      #("token", json.string(token)),
      #("voter_swimmer", json.string(voter_swimmer_id)),
      #("candidate", json.string(candidate_id)),
    ])

  supabase.post_json(
    "/rest/v1/rpc/cast_vote",
    json.to_string(body),
    cast_vote_decoder(),
    message,
  )
}

pub fn cast_vote_decoder() -> decode.Decoder(String) {
  decode.string
}

// -----------------------------------------------------------------------------
// Admin authentication
// -----------------------------------------------------------------------------

pub fn login(
  email: String,
  password: String,
  message: fn(Result(String, rsvp.Error(String))) -> msg,
) -> effect.Effect(msg) {
  let body =
    json.object([
      #("email", json.string(email)),
      #("password", json.string(password)),
    ])

  supabase.post_json(
    "/auth/v1/token?grant_type=password",
    json.to_string(body),
    access_token_decoder(),
    message,
  )
}

pub fn access_token_decoder() -> decode.Decoder(String) {
  use token <- decode.field("access_token", decode.string)
  decode.success(token)
}

// -----------------------------------------------------------------------------
// Admin roster
// -----------------------------------------------------------------------------

pub fn get_admin_roster(
  jwt: String,
  message: fn(Result(List(AdminRow), rsvp.Error(String))) -> msg,
) -> effect.Effect(msg) {
  supabase.post_json_with_auth(
    "/rest/v1/rpc/get_admin_roster",
    jwt,
    "{}",
    admin_roster_decoder(),
    message,
  )
}

pub fn admin_roster_decoder() -> decode.Decoder(List(AdminRow)) {
  decode.list(types.admin_row_decoder())
}

// -----------------------------------------------------------------------------
// Admin results
// -----------------------------------------------------------------------------

pub fn get_results(
  jwt: String,
  message: fn(Result(List(ResultRow), rsvp.Error(String))) -> msg,
) -> effect.Effect(msg) {
  supabase.post_json_with_auth(
    "/rest/v1/rpc/get_results",
    jwt,
    "{}",
    results_decoder(),
    message,
  )
}

pub fn results_decoder() -> decode.Decoder(List(ResultRow)) {
  types.result_list_decoder()
}

// -----------------------------------------------------------------------------
// Open / close voting
// -----------------------------------------------------------------------------

pub fn set_voting_open(
  jwt: String,
  open: Bool,
  message: fn(Result(Nil, rsvp.Error(String))) -> msg,
) -> effect.Effect(msg) {
  let body =
    json.object([
      #("open", json.bool(open)),
    ])

  supabase.post_with_auth(
    "/rest/v1/rpc/set_voting_open",
    jwt,
    json.to_string(body),
    message,
  )
}

// -----------------------------------------------------------------------------
// Notify parents
// -----------------------------------------------------------------------------

pub fn notify_parents(
  jwt: String,
  message: fn(Result(Nil, rsvp.Error(String))) -> msg,
) -> effect.Effect(msg) {
  supabase.post_with_auth("/functions/v1/notify-parents", jwt, "{}", message)
}

// -----------------------------------------------------------------------------
// Add Family
// -----------------------------------------------------------------------------

pub fn add_family(
  p_family_email: String,
  message: fn(Result(String, rsvp.Error(String))) -> msg,
) -> effect.Effect(msg) {
  let body =
    json.object([
      #("p_family_email", json.string(p_family_email)),
    ])

  supabase.post_json(
    "/rest/v1/rpc/add_family",
    json.to_string(body),
    add_family_decoder(),
    message,
  )
}

pub fn add_family_decoder() -> decode.Decoder(String) {
  decode.string
}

// -----------------------------------------------------------------------------
// Get Admin Families
// -----------------------------------------------------------------------------
pub fn get_admin_families(
  message: fn(Result(List(AdminFamily), rsvp.Error(String))) -> msg,
) -> effect.Effect(msg) {
  supabase.get_json(
    "/rest/v1/rpc/get_admin_families",
    admin_family_decoder(),
    message,
  )
}

pub fn admin_family_decoder() -> decode.Decoder(List(AdminFamily)) {
  types.admin_family_list_decoder()
}
