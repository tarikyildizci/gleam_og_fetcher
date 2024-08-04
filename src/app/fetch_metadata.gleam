import gleam/http/request
import gleam/httpc
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/regex
import gleam/result
import gleam/uri

type OpenGraph {
  Title(String)
  Type(String)
  Description(String)
  URL(String)
  ImageUrl(String)
  ImageAlt(String)
  ImageWidth(String)
  ImageHeight(String)
  SiteName(String)
  Locale(String)
}

pub fn fetch_metadata(url: String) -> Result(List(#(String, json.Json)), String) {
  use uri <- result.try(
    uri.parse(url)
    |> result.replace_error("Failed to parse url"),
  )

  use req <- result.try({
    let req = request.from_uri(uri)
    result.replace_error(req, "Failed to create request")
  })

  let resp = httpc.send(req) |> result.replace_error("Failed to fetch.")

  case resp {
    Ok(resp) ->
      Ok({
        get_open_graphs_from_html(resp.body)
        |> list.map(open_graph_to_tuple)
      })
    Error(e) -> Error(e)
  }
}

// <meta\s+[^>]*property\s*=\s*["']([^"']*)["'][^>]*content\s*=\s*["']([^"']*)["'][^>]*>|<meta\s+[^>]*content\s*=\s*["']([^"']*)["'][^>]*property\s*=\s*["']([^"']*)["'][^>]*>

fn get_open_graphs_from_html(html: String) -> List(OpenGraph) {
  let assert Ok(og_regex) =
    regex.from_string(
      "<meta\\s+[^>]*property\\s*=\\s*[\"']([^\"']*)[\"'][^>]*content\\s*=\\s*[\"']([^\"']*)[\"'][^>]*>|<meta\\s+[^>]*content\\s*=\\s*[\"']([^\"']*)[\"'][^>]*property\\s*=\\s*[\"']([^\"']*)[\"'][^>]*>",
    )

  regex.scan(og_regex, html)
  |> list.map(get_og_meta_from_meta_tag_match)
  |> list_filter_none
}

fn get_og_meta_from_meta_tag_match(match: regex.Match) -> Option(OpenGraph) {
  case match.submatches {
    [Some(property), Some(content)] -> {
      case property {
        "og:title" -> Some(Title(content))
        "og:type" -> Some(Type(content))
        "og:url" -> Some(URL(content))
        "og:description" -> Some(Description(content))
        "og:site_name" -> Some(SiteName(content))
        "og:locale" -> Some(Locale(content))
        "og:image" -> Some(ImageUrl(content))
        "og:image:alt" -> Some(ImageAlt(content))
        "og:image:width" -> Some(ImageWidth(content))
        "og:image:height" -> Some(ImageHeight(content))
        _ -> None
      }
    }
    _ -> None
  }
}

fn open_graph_to_tuple(og: OpenGraph) -> #(String, json.Json) {
  case og {
    Title(title) -> #("title", json.string(title))
    Type(og_type) -> #("type", json.string(og_type))
    Description(description) -> #("description", json.string(description))
    URL(url) -> #("url", json.string(url))
    ImageUrl(url) -> #("image", json.string(url))
    ImageAlt(alt) -> #("image:alt", json.string(alt))
    ImageWidth(width) -> #("image:width", json.string(width))
    ImageHeight(height) -> #("image:height", json.string(height))
    SiteName(site_name) -> #("site_name", json.string(site_name))
    Locale(locale) -> #("locale", json.string(locale))
  }
}

fn list_filter_none(options: List(Option(a))) -> List(a) {
  list.filter_map(options, fn(x) {
    case x {
      Some(x) -> Ok(x)
      None -> Error(Nil)
    }
  })
}
