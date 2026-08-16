import api.{type FamilyBallotRow, FamilyBallotRow}
import family
import gleam/list
import gleam/option.{None, Some}
import gleeunit/should
import rsvp
import types.{
  type Candidate, type ChildBallot, Candidate, ChildBallot, NotSubmitted,
  Submitted, VotedFor,
}

const token = "family-token"

fn candidates() -> List(Candidate) {
  [
    Candidate(id: "candidate-1", name: "Nekesa Wesonga"),
    Candidate(id: "candidate-2", name: "Wambui Wesonga"),
  ]
}

fn ballot() -> List(FamilyBallotRow) {
  [
    FamilyBallotRow(
      swimmer_id: "voter-1",
      swimmer_name: "Akinyi Wesonga",
      has_voted: False,
      voting_open: True,
      voted_for_name: None,
    ),
    FamilyBallotRow(
      swimmer_id: "voter-2",
      swimmer_name: "Baraka Wesonga",
      has_voted: True,
      voting_open: True,
      voted_for_name: Some("Nekesa Wesonga"),
    ),
  ]
}

fn ready_to_submit() -> family.State {
  let candidate = Candidate(id: "candidate-1", name: "Nekesa Wesonga")
  family.Ready(
    voting_open: True,
    children: [
      ChildBallot(
        swimmer_id: "voter-1",
        swimmer_name: "Akinyi Wesonga",
        has_voted: False,
        search_text: candidate.name,
        selected_candidate: Some(candidate),
        status: NotSubmitted,
      ),
    ],
    candidates: [candidate],
  )
}

fn only_child(state: family.State) -> ChildBallot {
  let assert family.Ready(_, [child], _) = state
  child
}

pub fn family_keeps_roster_when_roster_arrives_first_test() {
  let #(after_roster, _) =
    family.update(family.Loading, token, family.GotRoster(Ok(candidates())))
  let #(ready, _) =
    family.update(after_roster, token, family.GotFamilyBallot(Ok(ballot())))

  let assert family.Ready(voting_open, children, loaded_candidates) = ready
  voting_open |> should.be_true
  loaded_candidates |> should.equal(candidates())
  children |> list.length |> should.equal(2)

  let assert [_, voted_child] = children
  voted_child.has_voted |> should.be_true
  voted_child.status |> should.equal(VotedFor("Nekesa Wesonga"))
}

pub fn family_adds_roster_when_ballot_arrives_first_test() {
  let #(after_ballot, _) =
    family.update(family.Loading, token, family.GotFamilyBallot(Ok(ballot())))
  let #(ready, _) =
    family.update(after_ballot, token, family.GotRoster(Ok(candidates())))

  let assert family.Ready(voting_open, children, loaded_candidates) = ready
  voting_open |> should.be_true
  children |> list.length |> should.equal(2)
  loaded_candidates |> should.equal(candidates())
}

pub fn empty_family_ballot_shows_invalid_link_error_test() {
  let #(updated, _) =
    family.update(family.Loading, token, family.GotFamilyBallot(Ok([])))

  updated
  |> should.equal(family.LoadFailed(
    "That link isn't valid. Contact your team manager for a new one.",
  ))
}

pub fn failed_family_ballot_shows_loading_error_test() {
  let #(updated, _) =
    family.update(
      family.Loading,
      token,
      family.GotFamilyBallot(Error(rsvp.NetworkError)),
    )

  updated
  |> should.equal(family.LoadFailed(
    "Something went wrong loading your ballot. Please try again.",
  ))
}

pub fn successful_vote_records_selected_candidate_test() {
  let #(updated, _) =
    family.update(
      ready_to_submit(),
      token,
      family.VoteResult(swimmer_id: "voter-1", result: Ok("ok")),
    )

  let child = only_child(updated)
  child.has_voted |> should.be_true
  child.status |> should.equal(VotedFor("Nekesa Wesonga"))
}

pub fn rejected_vote_does_not_mark_child_as_voted_test() {
  let #(updated, _) =
    family.update(
      ready_to_submit(),
      token,
      family.VoteResult(swimmer_id: "voter-1", result: Ok("voting_closed")),
    )

  let child = only_child(updated)
  child.has_voted |> should.be_false
  child.status
  |> should.equal(Submitted(
    "Voting just closed — sorry, this vote couldn't be recorded.",
  ))
}

pub fn network_failure_does_not_mark_child_as_voted_test() {
  let #(updated, _) =
    family.update(
      ready_to_submit(),
      token,
      family.VoteResult(swimmer_id: "voter-1", result: Error(rsvp.NetworkError)),
    )

  let child = only_child(updated)
  child.has_voted |> should.be_false
  child.status |> should.equal(Submitted("Network error — please try again."))
}
