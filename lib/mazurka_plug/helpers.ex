defmodule Mazurka.Plug.Helpers do
  alias Plug.Conn

  def get_accepts(conn) do
    conn
    |> Conn.get_req_header("accept")
    |> Stream.map(&Conn.Utils.list/1)
    |> Stream.concat()
    |> Stream.flat_map(fn(type) ->
      case Conn.Utils.media_type(type) do
        {:ok, type, subtype, params} ->
          [{type, subtype, params}]
        _ ->
          []
      end
    end)
    |> Enum.to_list()
  end

  def get_params(conn) do
    %{
      # sent in body, perhaps in json %{"foo" => "bar"}
      body_params: b_params,

      # sent in query eg. ?foo=bar
      query_params: q_params,

      # all params, aka both of the above
      params: params
    } = conn = Plug.Conn.fetch_query_params(conn)

    b_params = case b_params do
                 %Plug.Conn.Unfetched{} ->
                   %{}
                 _ ->
                   b_params
               end

    input = Map.merge(q_params, b_params)
    # these params are set by concerto via the matching route path /podcasts/@podcast
    params = conn.private[:concerto_params] || %{}

    {params, input, conn}
  end

  def handle_body(conn, body, {type, subtype, _} = content_type, serialize) do
    body = serialize.(content_type, body)
    %{conn | resp_body: body, state: :set}
    |> Conn.put_resp_content_type(type <> "/" <> subtype)
  end

  def handle_transition(%{private: %{mazurka_transition: transition}, status: status} = conn) do
    %{conn | status: status || 303}
    |> Conn.put_resp_header("location", to_string(transition))
  end
  def handle_transition(conn) do
    conn
  end

  # TODO make this header configurable
  def handle_invalidation(%{private: %{mazurka_invalidations: invalidations}} = conn) do
    Conn.put_resp_header(conn, "x-invalidates", Enum.join(invalidations, ","))
  end
  def handle_invalidation(conn) do
    conn
  end

  def handle_response(%{status: nil} = conn) do
    %{conn | status: 200}
  end
  def handle_response(conn) do
    conn
  end
end
