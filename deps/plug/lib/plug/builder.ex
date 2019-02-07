defmodule Plug.Builder do
  @moduledoc """
  Conveniences for building plugs.

  This module can be `use`-d into a module in order to build
  a plug pipeline:

      defmodule MyApp do
        use Plug.Builder

        plug Plug.Logger
        plug :hello, upper: true

        # A function from another module can be plugged too, provided it's
        # imported into the current module first.
        import AnotherModule, only: [interesting_plug: 2]
        plug :interesting_plug

        def hello(conn, opts) do
          body = if opts[:upper], do: "WORLD", else: "world"
          send_resp(conn, 200, body)
        end
      end

  Multiple plugs can be defined with the `plug/2` macro, forming a pipeline.
  The plugs in the pipeline will be executed in the order they've been added
  through the `plug/2` macro. In the example above, `Plug.Logger` will be
  called first and then the `:hello` function plug will be called on the
  resulting connection.

  `Plug.Builder` also imports the `Plug.Conn` module, making functions like
  `send_resp/3` available.

  ## Options

  When used, the following options are accepted by `Plug.Builder`:

    * `:log_on_halt` - accepts the level to log whenever the request is halted
    * `:init_mode` - the environment to initialize the plug's options, one of
      `:compile` or `:runtime`. Defaults `:compile`.

  ## Plug behaviour

  Internally, `Plug.Builder` implements the `Plug` behaviour, which means both
  the `init/1` and `call/2` functions are defined.

  By implementing the Plug API, `Plug.Builder` guarantees this module is a plug
  and can be handed to a web server or used as part of another pipeline.

  ## Overriding the default Plug API functions

  Both the `init/1` and `call/2` functions defined by `Plug.Builder` can be
  manually overridden. For example, the `init/1` function provided by
  `Plug.Builder` returns the options that it receives as an argument, but its
  behaviour can be customized:

      defmodule PlugWithCustomOptions do
        use Plug.Builder
        plug Plug.Logger

        def init(opts) do
          opts
        end
      end

  The `call/2` function that `Plug.Builder` provides is used internally to
  execute all the plugs listed using the `plug` macro, so overriding the
  `call/2` function generally implies using `super` in order to still call the
  plug chain:

      defmodule PlugWithCustomCall do
        use Plug.Builder
        plug Plug.Logger
        plug Plug.Head

        def call(conn, opts) do
          conn
          |> super(opts) # calls Plug.Logger and Plug.Head
          |> assign(:called_all_plugs, true)
        end
      end

  ## Halting a plug pipeline

  A plug pipeline can be halted with `Plug.Conn.halt/1`. The builder will
  prevent further plugs downstream from being invoked and return the current
  connection. In the following example, the `Plug.Logger` plug never gets
  called:

      defmodule PlugUsingHalt do
        use Plug.Builder

        plug :stopper
        plug Plug.Logger

        def stopper(conn, _opts) do
          halt(conn)
        end
      end
  """

  @type plug :: module | atom

  @doc false
  defmacro __using__(opts) do
    quote do
      @behaviour Plug
      @plug_builder_opts unquote(opts)

      def init(opts) do
        opts
      end

      def call(conn, opts) do
        plug_builder_call(conn, opts)
      end

      defoverridable init: 1, call: 2

      import Plug.Conn
      import Plug.Builder, only: [plug: 1, plug: 2, builder_opts: 0]

      Module.register_attribute(__MODULE__, :plugs, accumulate: true)
      @before_compile Plug.Builder
    end
  end

  @doc false
  defmacro __before_compile__(env) do
    plugs = Module.get_attribute(env.module, :plugs)

    plugs =
      if builder_ref = get_plug_builder_ref(env.module) do
        traverse(plugs, builder_ref)
      else
        plugs
      end

    builder_opts = Module.get_attribute(env.module, :plug_builder_opts)
    {conn, body} = Plug.Builder.compile(env, plugs, builder_opts)

    quote do
      defp plug_builder_call(unquote(conn), opts), do: unquote(body)
    end
  end

  defp traverse(tuple, ref) when is_tuple(tuple) do
    tuple |> Tuple.to_list() |> traverse(ref) |> List.to_tuple()
  end

  defp traverse(map, ref) when is_map(map) do
    map |> Map.to_list() |> traverse(ref) |> Map.new()
  end

  defp traverse(list, ref) when is_list(list) do
    Enum.map(list, &traverse(&1, ref))
  end

  defp traverse(ref, ref) do
    {:unquote, [], [quote(do: opts)]}
  end

  defp traverse(term, _ref) do
    term
  end

  @doc """
  A macro that stores a new plug. `opts` will be passed unchanged to the new
  plug.

  This macro doesn't add any guards when adding the new plug to the pipeline;
  for more information about adding plugs with guards see `compile/1`.

  ## Examples

      plug Plug.Logger               # plug module
      plug :foo, some_options: true  # plug function

  """
  defmacro plug(plug, opts \\ []) do
    quote do
      @plugs {unquote(plug), unquote(opts), true}
    end
  end

  @doc """
  Annotates a plug will receive the options given
  to the current module itself as arguments.

  Imagine the following plug:

      defmodule MyPlug do
        use Plug.Builder

        plug :inspect_opts, builder_opts()

        defp inspect_opts(conn, opts) do
          IO.inspect(opts)
          conn
        end
      end

  When plugged as:

      plug MyPlug, custom: :options

  It will print `[custom: :options]` as the builder options
  were passed to the inner plug.

  Note you only pass `builder_opts()` to **function plugs**.
  You cannot use `builder_opts()` with module plugs because
  their options are evaluated at compile time. If you need
  to pass `builder_opts()` to a module plug, you can wrap
  the module plug in function. To be precise, do not do this:

      plug Plug.Parsers, builder_opts()

  Instead do this:

      plug :custom_plug_parsers, builder_opts()

      defp custom_plug_parsers(conn, opts) do
        Plug.Parsers.call(conn, Plug.Parsers.init(opts))
      end
  """
  defmacro builder_opts() do
    quote do
      Plug.Builder.__builder_opts__(__MODULE__)
    end
  end

  @doc false
  def __builder_opts__(module) do
    get_plug_builder_ref(module) || generate_plug_builder_ref(module)
  end

  defp get_plug_builder_ref(module) do
    Module.get_attribute(module, :plug_builder_ref)
  end

  defp generate_plug_builder_ref(module) do
    ref = make_ref()
    Module.put_attribute(module, :plug_builder_ref, ref)
    ref
  end

  @doc """
  Compiles a plug pipeline.

  Each element of the plug pipeline (according to the type signature of this
  function) has the form:

      {plug_name, options, guards}

  Note that this function expects a reversed pipeline (with the last plug that
  has to be called coming first in the pipeline).

  The function returns a tuple with the first element being a quoted reference
  to the connection and the second element being the compiled quoted pipeline.

  ## Examples

      Plug.Builder.compile(env, [
        {Plug.Logger, [], true}, # no guards, as added by the Plug.Builder.plug/2 macro
        {Plug.Head, [], quote(do: a when is_binary(a))}
      ], [])

  """
  @spec compile(Macro.Env.t(), [{plug, Plug.opts(), Macro.t()}], Keyword.t()) ::
          {Macro.t(), Macro.t()}
  def compile(env, pipeline, builder_opts) do
    conn = quote do: conn
    init_mode = builder_opts[:init_mode] || :compile

    unless init_mode in [:compile, :runtime] do
      raise ArgumentError, """
      invalid :init_mode when compiling #{inspect(env.module)}.

      Supported values include :compile or :runtime. Got: #{inspect(init_mode)}
      """
    end

    ast =
      Enum.reduce(pipeline, conn, fn {plug, opts, guards}, acc ->
        {plug, opts, guards}
        |> init_plug(init_mode)
        |> quote_plug(acc, env, builder_opts)
      end)

    {conn, ast}
  end

  # Initializes the options of a plug in the configured init_mode.
  defp init_plug({plug, opts, guards}, init_mode) do
    case Atom.to_charlist(plug) do
      ~c"Elixir." ++ _ -> init_module_plug(plug, opts, guards, init_mode)
      _ -> init_fun_plug(plug, opts, guards)
    end
  end

  defp init_module_plug(plug, opts, guards, :compile) do
    initialized_opts = plug.init(opts)

    if function_exported?(plug, :call, 2) do
      {:module, plug, escape(initialized_opts), guards}
    else
      raise ArgumentError, message: "#{inspect(plug)} plug must implement call/2"
    end
  end

  defp init_module_plug(plug, opts, guards, :runtime) do
    {:module, plug, quote(do: unquote(plug).init(unquote(escape(opts)))), guards}
  end

  defp init_fun_plug(plug, opts, guards) do
    {:function, plug, escape(opts), guards}
  end

  defp escape(opts) do
    Macro.escape(opts, unquote: true)
  end

  # `acc` is a series of nested plug calls in the form of
  # plug3(plug2(plug1(conn))). `quote_plug` wraps a new plug around that series
  # of calls.
  defp quote_plug({plug_type, plug, opts, guards}, acc, env, builder_opts) do
    call = quote_plug_call(plug_type, plug, opts)

    error_message =
      case plug_type do
        :module -> "expected #{inspect(plug)}.call/2 to return a Plug.Conn"
        :function -> "expected #{plug}/2 to return a Plug.Conn"
      end <> ", all plugs must receive a connection (conn) and return a connection"

    {fun, meta, [arg, [do: clauses]]} =
      quote do
        case unquote(compile_guards(call, guards)) do
          %Plug.Conn{halted: true} = conn ->
            unquote(log_halt(plug_type, plug, env, builder_opts))
            conn

          %Plug.Conn{} = conn ->
            unquote(acc)

          other ->
            raise unquote(error_message) <> ", got: #{inspect(other)}"
        end
      end

    generated? = :erlang.system_info(:otp_release) >= '19'

    clauses =
      Enum.map(clauses, fn {:->, meta, args} ->
        if generated? do
          {:->, [generated: true] ++ meta, args}
        else
          {:->, Keyword.put(meta, :line, -1), args}
        end
      end)

    {fun, meta, [arg, [do: clauses]]}
  end

  defp quote_plug_call(:function, plug, opts) do
    quote do: unquote(plug)(conn, unquote(opts))
  end

  defp quote_plug_call(:module, plug, opts) do
    quote do: unquote(plug).call(conn, unquote(opts))
  end

  defp compile_guards(call, true) do
    call
  end

  defp compile_guards(call, guards) do
    quote do
      case true do
        true when unquote(guards) -> unquote(call)
        true -> conn
      end
    end
  end

  defp log_halt(plug_type, plug, env, builder_opts) do
    if level = builder_opts[:log_on_halt] do
      message =
        case plug_type do
          :module -> "#{inspect(env.module)} halted in #{inspect(plug)}.call/2"
          :function -> "#{inspect(env.module)} halted in #{inspect(plug)}/2"
        end

      quote do
        require Logger
        # Matching, to make Dialyzer happy on code executing Plug.Builder.compile/3
        _ = Logger.unquote(level)(unquote(message))
      end
    else
      nil
    end
  end
end
