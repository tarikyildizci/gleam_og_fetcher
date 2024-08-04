import app/fetch_metadata.{fetch_metadata}
import app/web
import gleam/http.{Get}
import gleam/json
import gleam/string_builder
import wisp.{type Request, type Response, get_query}

pub fn handle_request(req: Request) -> Response {
  use req <- web.middleware(req)

  // Wisp doesn't have a special router abstraction, instead we recommend using
  // regular old pattern matching. This is faster than a router, is type safe,
  // and means you don't have to learn or be limited by a special DSL.
  //
  case wisp.path_segments(req) {
    ["ping"] -> ping(req)
    ["fetch_metadata"] -> fetch_url(req)
    _ -> wisp.not_found()
  }
}

fn fetch_url(req: Request) -> Response {
  let query = get_query(req)
  case query {
    [#("url", url)] -> {
      case req.method {
        Get -> {
          case fetch_metadata(url) {
            Ok(body) -> {
              wisp.ok()
              |> wisp.json_body(string_builder.from_string(
                json.object(body) |> json.to_string,
              ))
            }
            Error(e) ->
              wisp.internal_server_error()
              |> wisp.json_body(string_builder.from_string(e))
          }
        }
        _ -> wisp.method_not_allowed([Get])
      }
    }
    _ ->
      wisp.bad_request()
      |> wisp.json_body(string_builder.from_string("Url is required"))
  }
}

fn ping(req: Request) -> Response {
  // The home page can only be accessed via GET requests, so this middleware is
  // used to return a 405: Method Not Allowed response for all other methods.
  use <- wisp.require_method(req, Get)

  wisp.ok()
  |> wisp.json_body(string_builder.from_string("Pong!"))
}
