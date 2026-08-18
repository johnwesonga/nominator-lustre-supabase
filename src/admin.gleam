import api
import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import gleam/string
import lustre/attribute
import lustre/effect
import lustre/element
import lustre/element/html
import lustre/event
import rsvp
import types.{type AdminFamily, type AdminRow, type ResultRow, AdminRow}

pub type State {
  LoggedOut(email: String, password: String, error: option.Option(String))
  LoadingDashboard(jwt: String)
  LoggedIn(
    jwt: String,
    roster: List(AdminRow),
    results: List(ResultRow),
    families: List(AdminFamily),
    management: ManagementForm,
    notice: option.Option(String),
    filter_text: String,
    busy: Bool,
  )
}

pub type ManagementMode {
  NewFamily
}

pub type ManagementForm {
  ManagementForm(mode: ManagementMode, email: String)
}

pub type Msg {
  EmailInput(String)
  PasswordInput(String)
  SubmitLogin
  LoginResult(Result(String, rsvp.Error(String)))
  GotRoster(Result(List(AdminRow), rsvp.Error(String)))
  GotResults(Result(List(ResultRow), rsvp.Error(String)))
  GotFamilies(Result(List(AdminFamily), rsvp.Error(String)))
  FilterInput(String)
  Refresh
  SetVoting(Bool)
  VotingUpdated(Bool, Result(Nil, rsvp.Error(String)))
  NotifyParents
  ParentsNotified(Result(Nil, rsvp.Error(String)))
  LogOut
  StartNewFamily
}

pub fn init() -> #(State, effect.Effect(Msg)) {
  #(LoggedOut(email: "", password: "", error: None), effect.none())
}

pub fn update(state: State, msg: Msg) -> #(State, effect.Effect(Msg)) {
  case msg {
    EmailInput(email) ->
      case state {
        LoggedOut(_, password, error) -> #(
          LoggedOut(email:, password:, error:),
          effect.none(),
        )
        _ -> #(state, effect.none())
      }
    PasswordInput(password) ->
      case state {
        LoggedOut(email, _, error) -> #(
          LoggedOut(email:, password:, error:),
          effect.none(),
        )
        _ -> #(state, effect.none())
      }
    SubmitLogin ->
      case state {
        LoggedOut(email, password, _) ->
          case email == "" || password == "" {
            True -> #(
              LoggedOut(
                email:,
                password:,
                error: Some("Enter your email and password."),
              ),
              effect.none(),
            )
            False -> #(
              LoggedOut(email:, password:, error: None),
              api.login(email, password, LoginResult),
            )
          }
        _ -> #(state, effect.none())
      }
    LoginResult(result) ->
      case result {
        Ok(jwt) -> #(LoadingDashboard(jwt), load_dashboard(jwt))
        Error(_) -> #(
          LoggedOut(
            email: logged_out_email(state),
            password: "",
            error: Some("Sign-in failed. Check your email and password."),
          ),
          effect.none(),
        )
      }
    GotRoster(result) -> got_roster(state, result)
    GotResults(result) -> got_results(state, result)
    GotFamilies(result) -> got_families(state, result)
    FilterInput(text) ->
      case state {
        LoggedIn(jwt, roster, results, families, management, notice, _, busy) -> #(
          LoggedIn(
            jwt:,
            roster:,
            results:,
            families:,
            management:,
            notice:,
            filter_text: text,
            busy:,
          ),
          effect.none(),
        )
        _ -> #(state, effect.none())
      }
    Refresh ->
      case state {
        LoggedIn(jwt, roster, results, families, management, _, filter_text, _) -> #(
          LoggedIn(
            jwt:,
            roster:,
            results:,
            families:,
            management:,
            notice: None,
            filter_text:,
            busy: True,
          ),
          load_dashboard(jwt),
        )
        _ -> #(state, effect.none())
      }
    SetVoting(open) ->
      case state {
        LoggedIn(jwt, roster, results, families, management, _, filter_text, _) -> #(
          LoggedIn(
            jwt:,
            roster:,
            results:,
            families:,
            management:,
            notice: None,
            filter_text:,
            busy: True,
          ),
          api.set_voting_open(jwt, open, fn(result) {
            VotingUpdated(open, result)
          }),
        )
        _ -> #(state, effect.none())
      }
    VotingUpdated(open, result) ->
      finish_action(state, result, case open {
        True -> "Voting is open."
        False -> "Voting is closed."
      })
    NotifyParents ->
      case state {
        LoggedIn(jwt, roster, results, families, management, _, filter_text, _) -> #(
          LoggedIn(
            jwt:,
            roster:,
            results:,
            families:,
            management:,
            notice: None,
            filter_text:,
            busy: True,
          ),
          api.notify_parents(jwt, ParentsNotified),
        )
        _ -> #(state, effect.none())
      }
    ParentsNotified(result) ->
      finish_action(state, result, "Parent notification request completed.")
    LogOut -> init()
    StartNewFamily -> set_management(state, ManagementForm(NewFamily, ""))
  }
}

fn new_management() -> ManagementForm {
  ManagementForm(NewFamily, "")
}

fn set_management(
  state: State,
  management: ManagementForm,
) -> #(State, effect.Effect(Msg)) {
  case state {
    LoggedIn(jwt, roster, results, families, _, notice, filter_text, busy) -> #(
      LoggedIn(
        jwt:,
        roster:,
        results:,
        families:,
        management:,
        notice:,
        filter_text:,
        busy:,
      ),
      effect.none(),
    )
    _ -> #(state, effect.none())
  }
}

fn logged_out_email(state: State) -> String {
  case state {
    LoggedOut(email, _, _) -> email
    _ -> ""
  }
}

fn load_dashboard(jwt: String) -> effect.Effect(Msg) {
  effect.batch([
    api.get_admin_roster(jwt, GotRoster),
    api.get_results(jwt, GotResults),
    api.get_admin_families(jwt, GotFamilies),
  ])
}

fn got_roster(
  state: State,
  response: Result(List(AdminRow), rsvp.Error(String)),
) -> #(State, effect.Effect(Msg)) {
  case response {
    Error(_) ->
      case state {
        LoadingDashboard(_) -> #(
          LoggedOut(
            email: "",
            password: "",
            error: Some(
              "Could not load the admin dashboard. Please sign in again.",
            ),
          ),
          effect.none(),
        )
        LoggedIn(jwt, roster, results, families, management, _, filter_text, _) -> #(
          LoggedIn(
            jwt:,
            roster:,
            results:,
            families:,
            management:,
            notice: Some("Refresh failed. Please try again."),
            filter_text:,
            busy: False,
          ),
          effect.none(),
        )
        _ -> #(state, effect.none())
      }
    Ok(loaded_roster) ->
      case state {
        LoadingDashboard(jwt) -> #(
          LoggedIn(
            jwt:,
            roster: loaded_roster,
            results: [],
            families: [],
            management: new_management(),
            notice: None,
            filter_text: "",
            busy: False,
          ),
          effect.none(),
        )
        LoggedIn(jwt, _, results, families, management, notice, filter_text, _) -> #(
          LoggedIn(
            jwt:,
            roster: loaded_roster,
            results:,
            families:,
            management:,
            notice:,
            filter_text:,
            busy: False,
          ),
          effect.none(),
        )
        _ -> #(state, effect.none())
      }
  }
}

fn got_results(
  state: State,
  response: Result(List(ResultRow), rsvp.Error(String)),
) -> #(State, effect.Effect(Msg)) {
  case response {
    Error(_) ->
      case state {
        LoadingDashboard(_) -> #(
          LoggedOut(
            email: "",
            password: "",
            error: Some(
              "Could not load the admin dashboard. Please sign in again.",
            ),
          ),
          effect.none(),
        )
        LoggedIn(jwt, roster, results, families, management, _, filter_text, _) -> #(
          LoggedIn(
            jwt:,
            roster:,
            results:,
            families:,
            management:,
            notice: Some("Refresh failed. Please try again."),
            filter_text:,
            busy: False,
          ),
          effect.none(),
        )
        _ -> #(state, effect.none())
      }
    Ok(results) ->
      case state {
        LoadingDashboard(jwt) -> #(
          LoggedIn(
            jwt:,
            roster: [],
            results:,
            families: [],
            management: new_management(),
            notice: None,
            filter_text: "",
            busy: False,
          ),
          effect.none(),
        )
        LoggedIn(jwt, roster, _, families, management, notice, filter_text, _) -> #(
          LoggedIn(
            jwt:,
            roster:,
            results:,
            families:,
            management:,
            notice:,
            filter_text:,
            busy: False,
          ),
          effect.none(),
        )
        _ -> #(state, effect.none())
      }
  }
}

fn got_families(
  state: State,
  response: Result(List(AdminFamily), rsvp.Error(String)),
) -> #(State, effect.Effect(Msg)) {
  case response {
    Error(_) ->
      case state {
        LoadingDashboard(_) -> #(
          LoggedOut(
            email: "",
            password: "",
            error: Some(
              "Could not load the admin dashboard. Please sign in again.",
            ),
          ),
          effect.none(),
        )
        LoggedIn(jwt, roster, results, families, management, _, filter_text, _) -> #(
          LoggedIn(
            jwt:,
            roster:,
            results:,
            families:,
            management:,
            notice: Some("Refresh failed. Please try again."),
            filter_text:,
            busy: False,
          ),
          effect.none(),
        )
        _ -> #(state, effect.none())
      }
    Ok(families) ->
      case state {
        LoadingDashboard(jwt) -> #(
          LoggedIn(
            jwt:,
            roster: [],
            results: [],
            families:,
            management: new_management(),
            notice: None,
            filter_text: "",
            busy: False,
          ),
          effect.none(),
        )
        LoggedIn(jwt, roster, results, _, management, notice, filter_text, _) -> #(
          LoggedIn(
            jwt:,
            roster:,
            results:,
            families:,
            management:,
            notice:,
            filter_text:,
            busy: False,
          ),
          effect.none(),
        )
        _ -> #(state, effect.none())
      }
  }
}

fn finish_action(
  state: State,
  result: Result(Nil, rsvp.Error(String)),
  success: String,
) {
  case state {
    LoggedIn(jwt, roster, results, families, management, _, filter_text, _) -> {
      let notice = case result {
        Ok(_) -> success
        Error(_) -> "The action failed. Please try again."
      }
      #(
        LoggedIn(
          jwt:,
          roster:,
          results:,
          families:,
          management:,
          notice: Some(notice),
          filter_text:,
          busy: False,
        ),
        effect.none(),
      )
    }
    _ -> #(state, effect.none())
  }
}

pub fn view(state: State) -> element.Element(Msg) {
  html.div([attribute.id("view-admin"), attribute.class("view active")], [
    case state {
      LoggedOut(email, password, error) -> view_login(email, password, error)
      LoadingDashboard(_) -> html.p([], [html.text("Loading dashboard...")])
      LoggedIn(
        _,
        roster,
        results,
        families,
        management,
        notice,
        filter_text,
        busy,
      ) ->
        view_dashboard(
          roster,
          results,
          families,
          management,
          notice,
          filter_text,
          busy,
        )
    },
  ])
}

fn view_login(email: String, password: String, error: option.Option(String)) {
  html.section([attribute.class("panel admin-login")], [
    html.h1([], [html.text("Admin sign in")]),
    html.p([], [
      html.text("Use the team manager account configured in Supabase."),
    ]),
    html.form([event.on_submit(fn(_) { SubmitLogin })], [
      html.label([], [html.text("Email")]),
      html.input([
        attribute.type_("email"),
        attribute.value(email),
        attribute.required(True),
        event.on_input(EmailInput),
      ]),
      html.label([], [html.text("Password")]),
      html.input([
        attribute.type_("password"),
        attribute.value(password),
        attribute.required(True),
        event.on_input(PasswordInput),
      ]),
      case error {
        Some(message) ->
          html.p([attribute.class("error")], [html.text(message)])
        None -> html.text("")
      },
      html.button(
        [attribute.class("btn btn-primary"), attribute.type_("submit")],
        [html.text("Sign in")],
      ),
    ]),
  ])
}

fn view_dashboard(
  roster: List(AdminRow),
  results: List(ResultRow),
  families: List(AdminFamily),
  management: ManagementForm,
  notice: option.Option(String),
  filter_text: String,
  busy: Bool,
) {
  let filtered =
    list.filter(roster, fn(row) {
      let query = string.lowercase(filter_text)
      string.contains(string.lowercase(row.swimmer_name), query)
      || string.contains(string.lowercase(row.family_email), query)
      || string.contains(
        string.lowercase(option.unwrap(row.group_name, "")),
        query,
      )
    })
  html.div([], [
    html.div([attribute.class("admin-head")], [
      html.div([], [
        html.h1([], [html.text("Admin dashboard")]),
        html.span([attribute.class("sub")], [
          html.text(int.to_string(list.length(roster)) <> " swimmers"),
        ]),
      ]),
      html.button([attribute.class("btn btn-ghost"), event.on_click(LogOut)], [
        html.text("Sign out"),
      ]),
    ]),
    html.div([attribute.class("controls")], [
      html.button(
        [
          attribute.class("btn btn-primary"),
          attribute.disabled(busy),
          event.on_click(SetVoting(True)),
        ],
        [html.text("Open voting")],
      ),
      html.button(
        [
          attribute.class("btn btn-ghost"),
          attribute.disabled(busy),
          event.on_click(SetVoting(False)),
        ],
        [html.text("Close voting")],
      ),
      html.button(
        [
          attribute.class("btn btn-ghost"),
          attribute.disabled(busy),
          event.on_click(NotifyParents),
        ],
        [html.text("Email all parents")],
      ),
      html.button(
        [
          attribute.class("btn btn-ghost"),
          attribute.disabled(busy),
          event.on_click(Refresh),
        ],
        [html.text("Refresh")],
      ),
    ]),
    case notice {
      Some(message) ->
        html.p([attribute.class("admin-notice")], [html.text(message)])
      None -> html.text("")
    },
    view_results(results),
    view_family_management(families, management, busy),
    html.section([attribute.class("panel")], [
      html.h3([], [html.text("Roster")]),
      html.input([
        attribute.class("roster-search"),
        attribute.type_("search"),
        attribute.placeholder("Search swimmer, family, or group..."),
        attribute.value(filter_text),
        event.on_input(FilterInput),
      ]),
      html.div([attribute.class("table-wrap")], [
        html.table([attribute.class("roster")], [
          html.thead([], [
            html.tr([], [
              html.th([], [html.text("Swimmer")]),
              html.th([], [html.text("Group")]),
              html.th([], [html.text("Family")]),
              html.th([], [html.text("Voted?")]),
            ]),
          ]),
          html.tbody([], list.map(filtered, view_roster_row)),
        ]),
      ]),
    ]),
  ])
}

fn view_family_management(
  families: List(AdminFamily),
  management: ManagementForm,
  busy: Bool,
) {
  html.section([attribute.class("panel family-management")], [
    html.div([attribute.class("family-management-head")], [
      html.div([], [
        html.h3([], [html.text("Families")]),
        html.p([], [
          html.text(
            int.to_string(list.length(families))
            <> " families. IDs and private voting tokens are generated automatically.",
          ),
        ]),
      ]),
      html.button(
        [
          attribute.class("btn btn-primary"),
          attribute.disabled(busy),
          event.on_click(StartNewFamily),
        ],
        [html.text("Add family")],
      ),
    ]),
    view_management_form(management, busy),
  ])
}

fn view_management_form(form: ManagementForm, busy: Bool) {
  let ManagementForm(mode, email) = form
  let title = case mode {
    NewFamily -> "Add family"
  }
  html.div([attribute.class("management-form")], [
    html.h4([], [html.text(title)]),
    case mode {
      NewFamily ->
        html.label([], [
          html.text("Parent or family email"),
          html.input([
            attribute.type_("email"),
            attribute.value(email),
            attribute.autocomplete("email"),
            attribute.disabled(busy),
          ]),
        ])
    },
    html.div([attribute.class("management-actions")], [
      html.button(
        [
          attribute.class("btn btn-primary"),
          attribute.disabled(busy),
        ],
        [html.text("Save")],
      ),
      html.button(
        [
          attribute.class("btn btn-ghost"),
          attribute.disabled(busy),
        ],
        [html.text("Cancel")],
      ),
    ]),
  ])
}

fn view_results(results: List(ResultRow)) {
  let leaders = list.filter(results, fn(row) { row.vote_count > 0 })
  let max_votes =
    results
    |> list.first
    |> result.map(fn(row) { row.vote_count })
    |> result.unwrap(0)
  html.section([attribute.class("panel")], [
    html.h3([], [html.text("Results")]),
    case leaders {
      [] -> html.p([], [html.text("No votes have been recorded yet.")])
      _ ->
        html.div(
          [],
          list.index_map(leaders, fn(row, index) {
            let width = case max_votes > 0 {
              True -> row.vote_count * 100 / max_votes
              False -> 0
            }
            html.div(
              [
                attribute.class(case index == 0 {
                  True -> "leaderboard-row top"
                  False -> "leaderboard-row"
                }),
              ],
              [
                html.span([attribute.class("rank")], [
                  html.text(int.to_string(index + 1)),
                ]),
                html.span([attribute.class("cand-name")], [
                  html.text(row.candidate_name),
                ]),
                html.div([attribute.class("bar-track")], [
                  html.div(
                    [
                      attribute.class("bar-fill"),
                      attribute.style("width", int.to_string(width) <> "%"),
                    ],
                    [],
                  ),
                ]),
                html.span([attribute.class("vote-count")], [
                  html.text(int.to_string(row.vote_count)),
                ]),
              ],
            )
          }),
        )
    },
  ])
}

fn view_roster_row(row: AdminRow) {
  let AdminRow(..) = row
  html.tr([], [
    html.td([], [html.text(row.swimmer_name)]),
    html.td([], [
      html.span([attribute.class("grp-tag")], [
        html.text(option.unwrap(row.group_name, "—")),
      ]),
    ]),
    html.td([], [html.text(row.family_email)]),
    html.td(
      [
        attribute.class(case row.has_voted {
          True -> "voted-yes"
          False -> "voted-no"
        }),
      ],
      [
        html.text(case row.has_voted {
          True -> "Yes"
          False -> "No"
        }),
      ],
    ),
  ])
}
