require "spec_helper"

describe Pliny::Log do
  before do
    @io = StringIO.new
    Pliny.stdout = @io
    Pliny.stderr = @io
  end

  after do
    Pliny.default_context = {}
  end

  it "logs in structured format" do
    expect(@io).to receive(:print).with("foo=bar baz=42\n")
    Pliny.log(foo: "bar", baz: 42)
  end

  it "re-raises errors" do
    assert_raises(RuntimeError) do
      Pliny.log(foo: "bar") do
        raise RuntimeError
      end
    end
  end

  it "supports blocks to log stages and elapsed" do
    expect(@io).to receive(:print).with("foo=bar at=start\n")
    expect(@io).to receive(:print).with("foo=bar at=finish elapsed=0.000\n")
    Pliny.log(foo: "bar") do
    end
  end

  it "merges default context" do
    Pliny.default_context = { app: "pliny" }
    expect(@io).to receive(:print).with("app=pliny foo=bar\n")
    Pliny.log(foo: "bar")
  end

  it "logs with just default context" do
    Pliny.default_context = { app: "pliny" }
    Pliny::RequestStore.store[:log_context] = { request_store: true }
    expect(@io).to receive(:print).with("app=pliny foo=bar\n")
    Pliny.log_with_default_context(foo: "bar")
  end

  it "logs without context" do
    Pliny.default_context = { app: "pliny" }
    expect(@io).to receive(:print).with("foo=bar\n")
    Pliny.log_without_context(foo: "bar")
  end

  it "merges context from RequestStore" do
    Pliny::RequestStore.store[:log_context] = { app: "pliny" }
    expect(@io).to receive(:print).with("app=pliny foo=bar\n")
    Pliny.log(foo: "bar")
  end

  it "supports a context" do
    expect(@io).to receive(:print).with("app=pliny foo=bar\n")
    Pliny.context(app: "pliny") do
      Pliny.log(foo: "bar")
    end
  end

  it "local context does not overwrite default context" do
    Pliny.default_context = { app: "pliny" }
    expect(@io).to receive(:print).with("app=not_pliny foo=bar\n")
    Pliny.log(app: 'not_pliny', foo: "bar")
    assert Pliny.default_context[:app] == "pliny"
  end

  it "local context does not overwrite request context" do
    Pliny::RequestStore.store[:log_context] = { app: "pliny" }
    expect(@io).to receive(:print).with("app=not_pliny foo=bar\n")
    Pliny.context(app: "not_pliny") do
      Pliny.log(foo: "bar")
    end
    assert Pliny::RequestStore.store[:log_context][:app] == "pliny"
  end

  it "local context does not propagate outside" do
    Pliny::RequestStore.store[:log_context] = { app: "pliny" }
    expect(@io).to receive(:print).with("app=pliny foo=bar\n")
    Pliny.context(app: "not_pliny", test: 123) do
    end
    Pliny.log(foo: "bar")
  end

  it "logs exceptions" do
    Pliny::RequestStore.store[:log_context] = { app: "pliny" }
    e = RuntimeError.new
    expect(@io).to receive(:print).with("app=pliny exception class=RuntimeError message=RuntimeError exception_id=#{e.object_id}\n")
    Pliny.log_exception(e)
  end

  describe "scrubbing" do

    it "allows a Proc to be assigned as a log scrubber" do
      Pliny.log_scrubber = -> (hash) { hash }

      begin
        Pliny.log_scrubber = Object.new
        fail
      rescue ArgumentError; end
    end

    describe "when a scrubber is present" do
      before do
        Pliny.log_scrubber = -> (hash) {
          Hash.new.tap do |h|
            hash.keys.each do |k|
              h[k] = "*SCRUBBED*"
            end
          end
        }
      end

      after do
        Pliny.log_scrubber = nil
      end

      it "scrubs the log when a scrubber is present" do
        Pliny::RequestStore.store[:log_context] = { app: "pliny" }

        expect(@io).to receive(:print).with("app=*SCRUBBED* foo=*SCRUBBED*\n")

        Pliny.log(foo: "bar")
      end
    end
  end
end
