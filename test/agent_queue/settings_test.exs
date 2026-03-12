defmodule AgentQueue.SettingsTest do
  use AgentQueue.DataCase

  alias AgentQueue.Settings

  describe "get/2" do
    test "returns the value for an existing key" do
      {:ok, _} = Settings.update_setting("test_key", "test_value")
      assert Settings.get("test_key") == "test_value"
    end

    test "returns default value for non-existent key" do
      assert Settings.get("non_existent_key", "default") == "default"
    end

    test "returns nil for non-existent key when no default provided" do
      assert Settings.get("non_existent_key") == nil
    end

    test "returns configured default for discovery_max_projects" do
      assert Settings.get("discovery_max_projects") == "10"
    end

    test "returns configured default for discovery_priority_mode" do
      assert Settings.get("discovery_priority_mode") == "most_recently_modified"
    end
  end

  describe "get_int/2" do
    test "returns integer value for numeric string" do
      {:ok, _} = Settings.update_setting("test_int", "42")
      assert Settings.get_int("test_int") == 42
    end

    test "returns nil for non-integer string" do
      {:ok, _} = Settings.update_setting("test_bad_int", "not_a_number")
      assert Settings.get_int("test_bad_int") == nil
    end

    test "returns default for non-existent key" do
      assert Settings.get_int("non_existent", 100) == 100
    end
  end

  describe "update_setting/2" do
    test "creates a new setting" do
      assert {:ok, setting} = Settings.update_setting("new_key", "new_value")
      assert setting.key == "new_key"
      assert setting.value == "new_value"
    end

    test "updates an existing setting" do
      {:ok, _} = Settings.update_setting("update_key", "old_value")
      assert {:ok, updated} = Settings.update_setting("update_key", "new_value")
      assert updated.value == "new_value"
      assert Settings.get("update_key") == "new_value"
    end
  end

  describe "all_settings/0" do
    test "returns all settings as a map" do
      {:ok, _} = Settings.update_setting("key1", "value1")
      {:ok, _} = Settings.update_setting("key2", "value2")

      settings = Settings.all_settings()

      assert is_map(settings)
      assert settings["key1"] == "value1"
      assert settings["key2"] == "value2"
    end
  end

  describe "all_settings_with_defaults/0" do
    test "includes default values for keys not in database" do
      # Clear existing settings
      AgentQueue.Repo.delete_all(AgentQueue.Settings.Setting)

      settings = Settings.all_settings_with_defaults()

      assert settings["discovery_max_projects"] == "10"
      assert settings["discovery_priority_mode"] == "most_recently_modified"
    end

    test "database values override defaults" do
      {:ok, _} = Settings.update_setting("discovery_max_projects", "25")

      settings = Settings.all_settings_with_defaults()

      assert settings["discovery_max_projects"] == "25"
      assert settings["discovery_priority_mode"] == "most_recently_modified"
    end
  end

  describe "get_discovery_max_projects/0" do
    test "returns the configured default" do
      assert Settings.get_discovery_max_projects() == 10
    end

    test "returns updated value" do
      {:ok, _} = Settings.update_setting("discovery_max_projects", "50")
      assert Settings.get_discovery_max_projects() == 50
    end
  end

  describe "get_discovery_priority_mode/0" do
    test "returns the configured default" do
      assert Settings.get_discovery_priority_mode() == "most_recently_modified"
    end

    test "returns updated value" do
      {:ok, _} = Settings.update_setting("discovery_priority_mode", "alphabetical")
      assert Settings.get_discovery_priority_mode() == "alphabetical"
    end

    test "falls back to default for invalid mode" do
      {:ok, _} = Settings.update_setting("discovery_priority_mode", "invalid_mode")
      assert Settings.get_discovery_priority_mode() == "most_recently_modified"
    end
  end

  describe "priority_modes/0" do
    test "returns list of valid priority modes" do
      modes = Settings.priority_modes()

      assert is_list(modes)
      assert "alphabetical" in modes
      assert "most_recently_modified" in modes
      assert "least_recently_scanned" in modes
      assert "random" in modes
    end
  end

  describe "ensure_defaults/0" do
    test "creates default settings when none exist" do
      # Clear existing settings
      AgentQueue.Repo.delete_all(AgentQueue.Settings.Setting)

      :ok = Settings.ensure_defaults()

      assert Settings.get("discovery_max_projects") == "10"
      assert Settings.get("discovery_priority_mode") == "most_recently_modified"
    end

    test "does not overwrite existing settings" do
      {:ok, _} = Settings.update_setting("discovery_max_projects", "999")

      :ok = Settings.ensure_defaults()

      assert Settings.get("discovery_max_projects") == "999"
    end
  end
end
