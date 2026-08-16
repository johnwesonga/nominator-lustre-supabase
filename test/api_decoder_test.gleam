import api
import gleam/dynamic/decode
import gleam/json
import gleeunit/should

fn should_reject(payload: String, decoder: decode.Decoder(a)) -> Nil {
  let _ = json.parse(payload, decoder) |> should.be_error
  Nil
}

pub fn family_ballot_decoder_rejects_invalid_payloads_test() {
  should_reject("{\"swimmer_id\":\"swimmer-1\"}", api.family_ballot_decoder())
  should_reject(
    "[{\"swimmer_id\":\"swimmer-1\",\"swimmer_name\":\"Nekesa\",\"has_voted\":false,\"voting_open\":true}]",
    api.family_ballot_decoder(),
  )
  should_reject(
    "[{\"swimmer_id\":\"swimmer-1\",\"swimmer_name\":\"Nekesa\",\"has_voted\":\"false\",\"voting_open\":true,\"voted_for_name\":null}]",
    api.family_ballot_decoder(),
  )
  should_reject(
    "[{\"swimmer_id\":\"swimmer-1\",\"swimmer_name\":\"Nekesa\",\"has_voted\":false,\"voting_open\":true,\"voted_for_name\":42}]",
    api.family_ballot_decoder(),
  )
}

pub fn roster_decoder_rejects_invalid_payloads_test() {
  should_reject(
    "{\"id\":\"swimmer-1\",\"name\":\"Nekesa\"}",
    api.roster_decoder(),
  )
  should_reject("[{\"id\":\"swimmer-1\"}]", api.roster_decoder())
  should_reject("[{\"id\":null,\"name\":\"Nekesa\"}]", api.roster_decoder())
}

pub fn cast_vote_decoder_rejects_non_string_response_test() {
  should_reject("{\"status\":\"ok\"}", api.cast_vote_decoder())
  should_reject("null", api.cast_vote_decoder())
}

pub fn access_token_decoder_rejects_invalid_payloads_test() {
  should_reject("{}", api.access_token_decoder())
  should_reject("{\"access_token\":123}", api.access_token_decoder())
  should_reject("\"admin-jwt\"", api.access_token_decoder())
}

pub fn admin_roster_decoder_rejects_invalid_payloads_test() {
  should_reject(
    "[{\"family_id\":\"family-1\",\"family_email\":\"family@example.com\",\"family_token\":\"token-1\",\"swimmer_id\":\"swimmer-1\",\"swimmer_name\":\"Nekesa\",\"group_name\":null}]",
    api.admin_roster_decoder(),
  )
  should_reject(
    "[{\"family_id\":\"family-1\",\"family_email\":\"family@example.com\",\"family_token\":\"token-1\",\"swimmer_id\":\"swimmer-1\",\"swimmer_name\":\"Nekesa\",\"group_name\":42,\"has_voted\":false}]",
    api.admin_roster_decoder(),
  )
  should_reject(
    "[{\"family_id\":\"family-1\",\"family_email\":\"family@example.com\",\"family_token\":\"token-1\",\"swimmer_id\":\"swimmer-1\",\"swimmer_name\":\"Nekesa\",\"group_name\":null,\"has_voted\":null}]",
    api.admin_roster_decoder(),
  )
}

pub fn results_decoder_rejects_invalid_payloads_test() {
  should_reject(
    "[{\"candidate_id\":\"swimmer-1\",\"candidate_name\":\"Nekesa\"}]",
    api.results_decoder(),
  )
  should_reject(
    "[{\"candidate_id\":\"swimmer-1\",\"candidate_name\":\"Nekesa\",\"vote_count\":\"3\"}]",
    api.results_decoder(),
  )
  should_reject(
    "[{\"candidate_id\":null,\"candidate_name\":\"Nekesa\",\"vote_count\":3}]",
    api.results_decoder(),
  )
}
