defmodule FarmbotOS.Lua.Ext.DataManipulationTest do
  use ExUnit.Case
  use Mimic
  setup :verify_on_exit!
  alias FarmbotOS.SysCalls.ResourceUpdate
  alias FarmbotOS.Lua.Ext.DataManipulation

  defstruct [:key, :value]
  def lua(test_name, lua_code) do
    FarmbotOS.Lua.eval_assertion(test_name, lua_code)
  end

  test "update_device()" do
    expect(ResourceUpdate, :update_resource, 1, fn "Device", nil, params ->
      assert %{"name" => "Test Farmbot"} == params
    end)

    lua_code = """
    update_device({name = "Test Farmbot"})
    return true
    """

    assert true == lua("update device test", lua_code)
  end

  test "get_device/0" do
    fake_device = %{fake: :device}
    expect(FarmbotCore.Asset, :device, 1, fn -> fake_device end)
    expect(FarmbotCore.Asset.Device, :render, 1, fn dev -> dev end)

    lua_code = """
    get_device()
    return true
    """

    assert true == lua("get device test", lua_code)
  end

  test "get_device/1" do
    fake_device = %{name: "my farmbot", id: 23}
    expect(FarmbotCore.Asset, :device, 1, fn -> fake_device end)
    expect(FarmbotCore.Asset.Device, :render, 1, fn dev -> dev end)

    lua_code = """
    return get_device("id") == 23
    """

    assert true == lua("get device test/1", lua_code)
  end

  test "get_fbos_config/1" do
    fake_config = %{id: 47}
    expect(FarmbotCore.Asset, :fbos_config, 1, fn -> fake_config end)
    expect(FarmbotCore.Asset.FbosConfig, :render, 1, fn params -> params end)

    lua_code = "return 47 == get_fbos_config(\"id\")"

    assert true == lua("get_fbos_config", lua_code)
  end

  test "get_fbos_config/0" do
    fake_config = %{id: 47, foo: "bar"}
    expect(FarmbotCore.Asset, :fbos_config, 1, fn -> fake_config end)
    expect(FarmbotCore.Asset.FbosConfig, :render, 1, fn params -> params end)

    lua_code = """
    c = get_fbos_config()
    return (c.id == 47) and (c.foo == "bar")
    """

    assert true == lua("get_fbos_config/1", lua_code)
  end

  test "get_firmware_config/1" do
    fake_config = %{id: 47}
    expect(FarmbotCore.Asset, :firmware_config, 1, fn -> fake_config end)

    expect(FarmbotCore.Asset.FirmwareConfig, :render, 1, fn params -> params end)

    lua_code = "return 47 == get_firmware_config(\"id\")"

    assert true == lua("get_firmware_config", lua_code)
  end

  test "get_firmware_config/0" do
    fake_config = %{id: 47, foo: "bar"}
    expect(FarmbotCore.Asset, :firmware_config, 1, fn -> fake_config end)

    expect(FarmbotCore.Asset.FirmwareConfig, :render, 1, fn params -> params end)

    lua_code = """
    c = get_firmware_config()
    return (c.id == 47) and (c.foo == "bar")
    """

    assert true == lua("get_firmware_config/1", lua_code)
  end

  test "new_sensor_reading" do
    expect(FarmbotCore.Asset, :new_sensor_reading!, 1, fn params -> params end)

    lua_code = """
    return new_sensor_reading({
      pin = 0,
      mode = 1,
      value = 2,
      x = 3,
      y = 4,
      z = 5,
    })
    """

    assert true == lua("new_sensor_reading/1", lua_code)
  end

  test "take_photo - OK" do
    mock = fn ("take-photo", %{}) -> :ok end
    expect(FarmbotOS.SysCalls.Farmware, :execute_script, mock)
    actual = DataManipulation.take_photo(:none, :lua)
    assert {[], :lua} == actual
  end

  test "take_photo - 'normal' errors" do
    mock = fn ("take-photo", %{}) -> {:error, "whatever"} end
    expect(FarmbotOS.SysCalls.Farmware, :execute_script, mock)
    actual = DataManipulation.take_photo(:none, :lua)
    assert {["whatever"], :lua} == actual
  end

  test "take_photo - malformed errors" do
    mock = fn ("take-photo", %{}) -> {:something_else, "whoops"} end
    expect(FarmbotOS.SysCalls.Farmware, :execute_script, mock)
    actual = DataManipulation.take_photo(:none, :lua)
    assert {[inspect({:something_else, "whoops"})], :lua} == actual
  end

  test "json_decode - OK" do
    actual = DataManipulation.json_decode(["{\"foo\":\"bar\"}"], :lua)
    assert {[[{"foo", "bar"}]], :lua} == actual
  end

  test "json_decode - Error" do
    actual = DataManipulation.json_decode(["no"], :lua)
    assert {[nil, "Error parsing JSON."], :lua} == actual
  end

  test "json_encode - OK" do
    actual = DataManipulation.json_encode([[{"foo", "bar"}]], :lua)
    assert {["{\"foo\":\"bar\"}"], :lua} == actual
  end

  test "env/1" do
    mock = fn -> [%__MODULE__{key: "foo", value: "bar"}] end
    expect(FarmbotCore.Asset, :list_farmware_env, 2, mock)
    results = DataManipulation.env(["foo"], :lua)
    assert {["bar"], :lua} == results
    results = DataManipulation.env(["wrong"], :lua)
    assert {[nil], :lua} == results
  end

  test "env/2 - OK" do
    mock = fn _, _ -> :ok end
    expect(FarmbotOS.SysCalls, :set_user_env, 1, mock)
    results = DataManipulation.env(["foo", "bar"], :lua)
    assert {["bar"], :lua} == results
  end

  test "env/2 - normal error" do
    mock = fn _, _ -> {:error, "reason"} end
    expect(FarmbotOS.SysCalls, :set_user_env, 1, mock)
    results = DataManipulation.env(["foo", "bar"], :lua)
    assert {[nil, "reason"], :lua} == results
  end

  test "env/2 - malformed error" do
    mock = fn _, _ -> :misc end
    expect(FarmbotOS.SysCalls, :set_user_env, 1, mock)
    results = DataManipulation.env(["foo", "bar"], :lua)
    assert {[nil, ":misc"], :lua} == results
  end
end
