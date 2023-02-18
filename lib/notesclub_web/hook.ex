defmodule LifeCycleHook do
  @moduledoc """
  Copy from [life_cycle_hook](https://github.com/nallwhy/life_cycle_hook)
  """

  import Phoenix.LiveView
  require Logger

  @life_cycle_stages [:mount, :handle_params, :handle_event, :handle_info]

  defmacro __using__(opts) do
    only = Keyword.get(opts, :only)
    except = Keyword.get(opts, :except)
    log_level = Keyword.get(opts, :log_level, :debug)
    log_context? = Keyword.get(opts, :log_context?, true)

    stages =
      case {only, except} do
        {nil, nil} -> @life_cycle_stages
        {only, nil} when is_list(only) -> @life_cycle_stages |> Enum.filter(&(&1 in only))
        {nil, except} when is_list(except) -> @life_cycle_stages |> Enum.reject(&(&1 in except))
        _ -> raise ":only and :except can'nt be given together to LifeCycleHook"
      end

    quote do
      on_mount({unquote(__MODULE__), %{stages: unquote(stages), log_level: unquote(log_level), log_context?: unquote(log_context?)}})
    end
  end

  def on_mount(%{stages: stages, log_level: log_level, log_context?: log_context?}, params, session, socket) do
    socket =
      stages
      |> Enum.reduce(socket, fn stage, socket ->
        case stage do
          :mount ->
            log_mount_life_cycle(socket, params, session, log_level, log_context?)

            socket

          stage ->
            socket |> attach_life_cycle_hook(stage, log_level, log_context?)
        end
      end)

    {:cont, socket}
  end

  defp log_mount_life_cycle(socket, params, session, log_level, log_context?) do
    message =
      [get_common_message(socket, :mount), get_connection_message(socket)]
      |> Enum.join(" ")

    log(log_level, message, log_context?, %{params: params, session: session, socket: socket})
  end

  defp attach_life_cycle_hook(socket, :handle_params, log_level, log_context?) do
    socket
    |> attach_hook(:life_cycle_hook, :handle_params, fn params, uri, socket ->
      message =
        [get_common_message(socket, :handle_params), get_connection_message(socket)]
        |> Enum.join(" ")

      log(log_level, message, log_context?, %{params: params, uri: uri, socket: socket})

      {:cont, socket}
    end)
  end

  defp attach_life_cycle_hook(socket, :handle_event, log_level, log_context?) do
    socket
    |> attach_hook(:life_cycle_hook, :handle_event, fn event, params, socket ->
      message =
        [get_common_message(socket, :handle_event), "event: #{event}"]
        |> Enum.join(" ")

      log(log_level, message, log_context?, %{event: event, params: params, socket: socket})

      {:cont, socket}
    end)
  end

  defp attach_life_cycle_hook(socket, :handle_info, log_level, log_context?) do
    socket
    |> attach_hook(:life_cycle_hook, :handle_info, fn message, socket ->
      message =
        [get_common_message(socket, :handle_info), "message: #{message}"]
        |> Enum.join(" ")

      log(log_level, message, log_context?, %{message: message, socket: socket})

      {:cont, socket}
    end)
  end

  defp log(log_level, message, log_context?, context) do
      Logger.log(log_level, message, ansi_color: :red)
      if log_context? and Logger.compare_levels(Logger.level(), log_level) != :gt, do: dbg(context)
  end

  defp get_connection_message(socket) do
    "connected: #{connected?(socket)}"
  end

  defp get_common_message(socket, stage) do
    module_name = socket.view |> inspect()

    "#{module_name} #{stage}"
  end
end
