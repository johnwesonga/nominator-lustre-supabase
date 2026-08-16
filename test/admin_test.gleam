import admin
import gleam/option.{None, Some}
import gleeunit/should
import rsvp
import types.{AdminRow, ResultRow}

fn logged_in_state(busy: Bool) -> admin.State {
  admin.LoggedIn(
    jwt: "admin-jwt",
    roster: [],
    results: [],
    notice: None,
    filter_text: "",
    busy:,
  )
}

pub fn admin_initializes_logged_out_test() {
  let #(state, _) = admin.init()

  state
  |> should.equal(admin.LoggedOut(email: "", password: "", error: None))
}

pub fn admin_updates_login_inputs_test() {
  let #(initial, _) = admin.init()
  let #(with_email, _) =
    admin.update(initial, admin.EmailInput("manager@example.com"))
  let #(with_password, _) =
    admin.update(with_email, admin.PasswordInput("secret-password"))

  with_password
  |> should.equal(admin.LoggedOut(
    email: "manager@example.com",
    password: "secret-password",
    error: None,
  ))
}

pub fn admin_rejects_empty_login_form_test() {
  let #(initial, _) = admin.init()
  let #(updated, _) = admin.update(initial, admin.SubmitLogin)

  updated
  |> should.equal(admin.LoggedOut(
    email: "",
    password: "",
    error: Some("Enter your email and password."),
  ))
}

pub fn successful_admin_login_starts_dashboard_loading_test() {
  let state =
    admin.LoggedOut(
      email: "manager@example.com",
      password: "secret-password",
      error: None,
    )
  let #(updated, _) =
    admin.update(state, admin.LoginResult(Ok("returned-admin-jwt")))

  updated |> should.equal(admin.LoadingDashboard("returned-admin-jwt"))
}

pub fn failed_admin_login_keeps_email_and_clears_password_test() {
  let state =
    admin.LoggedOut(
      email: "manager@example.com",
      password: "wrong-password",
      error: None,
    )
  let #(updated, _) =
    admin.update(state, admin.LoginResult(Error(rsvp.NetworkError)))

  updated
  |> should.equal(admin.LoggedOut(
    email: "manager@example.com",
    password: "",
    error: Some("Sign-in failed. Check your email and password."),
  ))
}

pub fn admin_logout_clears_session_and_dashboard_test() {
  let #(updated, _) = admin.update(logged_in_state(False), admin.LogOut)

  updated
  |> should.equal(admin.LoggedOut(email: "", password: "", error: None))
}

pub fn admin_roster_is_kept_when_results_arrive_first_test() {
  let jwt = "test-token"
  let result_row =
    ResultRow(
      candidate_id: "candidate-id",
      candidate_name: "Candidate",
      vote_count: 1,
    )
  let roster_row =
    AdminRow(
      family_id: "family-id",
      family_email: "family@example.com",
      family_token: "family-token",
      swimmer_id: "swimmer-id",
      swimmer_name: "Swimmer",
      group_name: None,
      has_voted: False,
    )

  let #(after_results, _) =
    admin.update(
      admin.LoadingDashboard(jwt),
      admin.GotResults(Ok([result_row])),
    )
  let #(after_roster, _) =
    admin.update(after_results, admin.GotRoster(Ok([roster_row])))

  let assert admin.LoggedIn(_, roster, results, _, _, _) = after_roster
  roster |> should.equal([roster_row])
  results |> should.equal([result_row])
}

pub fn set_voting_open_handles_success_test() {
  let state = logged_in_state(True)
  let #(updated, _) = admin.update(state, admin.VotingUpdated(True, Ok(Nil)))

  let assert admin.LoggedIn(_, _, _, notice, _, busy) = updated
  notice |> should.equal(Some("Voting is open."))
  busy |> should.be_false
}

pub fn notify_parents_handles_success_and_failure_test() {
  let state = logged_in_state(True)

  let #(succeeded, _) = admin.update(state, admin.ParentsNotified(Ok(Nil)))
  let assert admin.LoggedIn(_, _, _, success_notice, _, success_busy) =
    succeeded
  success_notice
  |> should.equal(Some("Parent notification request completed."))
  success_busy |> should.be_false

  let #(failed, _) =
    admin.update(state, admin.ParentsNotified(Error(rsvp.NetworkError)))
  let assert admin.LoggedIn(_, _, _, failure_notice, _, failure_busy) = failed
  failure_notice |> should.equal(Some("The action failed. Please try again."))
  failure_busy |> should.be_false
}
