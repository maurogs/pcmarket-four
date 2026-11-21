require "test_helper"
require "rake"

class ContextTaskTest < ActiveSupport::TestCase
  test "context:html renders both standalone HTML views" do
    Rails.application.load_tasks unless Rake::Task.task_defined?("context:html")
    task = Rake::Task["context:html"]
    task.reenable

    capture_io { task.invoke }

    english = Rails.root.join(".claude/context/project.html")
    spanish = Rails.root.join(".claude/context/project.es.html")

    assert File.exist?(english)
    assert File.exist?(spanish)

    english_body = english.read
    spanish_body = spanish.read

    assert_includes english_body, "<!DOCTYPE html>"
    assert_includes english_body, "prefers-color-scheme"
    assert_includes english_body, "Phase status"
    assert_includes english_body, "badge-success"
    assert_includes spanish_body, 'lang="es"'
    assert_includes spanish_body, "Estado de las fases"
    assert_not_includes english_body, "http://"
    assert_not_includes english_body, "https://cdn"
  end
end
