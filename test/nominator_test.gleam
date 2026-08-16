import api
import gleam/json
import gleam/option.{None, Some}
import gleeunit
import gleeunit/should
import types.{AdminRow, Candidate, ResultRow}

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn get_family_ballot_decodes_response_test() {
  let payload =
    "[{\"swimmer_id\":\"swimmer-1\",\"swimmer_name\":\"Nekesa Wesonga\",\"has_voted\":false,\"voting_open\":true,\"voted_for_name\":null},{\"swimmer_id\":\"swimmer-2\",\"swimmer_name\":\"Wambui Wesonga\",\"has_voted\":true,\"voting_open\":true,\"voted_for_name\":\"Nekesa Wesonga\"}]"

  let decoded = json.parse(payload, api.family_ballot_decoder())

  decoded
  |> should.equal(
    Ok([
      api.FamilyBallotRow(
        swimmer_id: "swimmer-1",
        swimmer_name: "Nekesa Wesonga",
        has_voted: False,
        voting_open: True,
        voted_for_name: None,
      ),
      api.FamilyBallotRow(
        swimmer_id: "swimmer-2",
        swimmer_name: "Wambui Wesonga",
        has_voted: True,
        voting_open: True,
        voted_for_name: Some("Nekesa Wesonga"),
      ),
    ]),
  )
}

pub fn get_roster_decodes_response_test() {
  let payload =
    "[{\"id\":\"swimmer-1\",\"name\":\"Nekesa Wesonga\"},{\"id\":\"swimmer-2\",\"name\":\"Wambui Wesonga\"}]"

  json.parse(payload, api.roster_decoder())
  |> should.equal(
    Ok([
      Candidate(id: "swimmer-1", name: "Nekesa Wesonga"),
      Candidate(id: "swimmer-2", name: "Wambui Wesonga"),
    ]),
  )
}

pub fn cast_vote_decodes_response_test() {
  json.parse("\"ok\"", api.cast_vote_decoder())
  |> should.equal(Ok("ok"))

  json.parse("\"already_voted\"", api.cast_vote_decoder())
  |> should.equal(Ok("already_voted"))
}

pub fn login_decodes_access_token_test() {
  let payload =
    "{\"access_token\":\"admin-jwt\",\"token_type\":\"bearer\",\"expires_in\":3600}"

  json.parse(payload, api.access_token_decoder())
  |> should.equal(Ok("admin-jwt"))
}

pub fn get_admin_roster_decodes_response_test() {
  let payload =
    "[{\"family_id\":\"family-1\",\"family_email\":\"family@example.com\",\"family_token\":\"token-1\",\"swimmer_id\":\"swimmer-1\",\"swimmer_name\":\"Nekesa Wesonga\",\"group_name\":null,\"has_voted\":false},{\"family_id\":\"family-2\",\"family_email\":\"other@example.com\",\"family_token\":\"token-2\",\"swimmer_id\":\"swimmer-2\",\"swimmer_name\":\"Wambui Wesonga\",\"group_name\":\"Senior\",\"has_voted\":true}]"

  json.parse(payload, api.admin_roster_decoder())
  |> should.equal(
    Ok([
      AdminRow(
        family_id: "family-1",
        family_email: "family@example.com",
        family_token: "token-1",
        swimmer_id: "swimmer-1",
        swimmer_name: "Nekesa Wesonga",
        group_name: None,
        has_voted: False,
      ),
      AdminRow(
        family_id: "family-2",
        family_email: "other@example.com",
        family_token: "token-2",
        swimmer_id: "swimmer-2",
        swimmer_name: "Wambui Wesonga",
        group_name: Some("Senior"),
        has_voted: True,
      ),
    ]),
  )
}

pub fn get_results_decodes_response_test() {
  let payload =
    "[{\"candidate_id\":\"swimmer-1\",\"candidate_name\":\"Nekesa Wesonga\",\"vote_count\":3},{\"candidate_id\":\"swimmer-2\",\"candidate_name\":\"Wambui Wesonga\",\"vote_count\":0}]"

  json.parse(payload, api.results_decoder())
  |> should.equal(
    Ok([
      ResultRow(
        candidate_id: "swimmer-1",
        candidate_name: "Nekesa Wesonga",
        vote_count: 3,
      ),
      ResultRow(
        candidate_id: "swimmer-2",
        candidate_name: "Wambui Wesonga",
        vote_count: 0,
      ),
    ]),
  )
}
