module Travis
  module Build
    class Script
      module Stages
        def run_stages
          STAGES[:builtin].each { |stage| run_builtin_stage(stage) }
          STAGES[:custom].each  { |stage| run_stage(stage) }
        end

        def run_stage(stage)
          if config[stage] && stage != :after_result
            run_custom_stage(stage)
          elsif respond_to?(stage, false) || stage == :after_result
            run_builtin_stage(stage)
          end
        end

        def run_custom_stage(stage)
          stage(stage) do
            Array(config[stage]).each do |command|
              cmd command
              result if stage == :script
            end
          end
        end

        def run_builtin_stage(stage)
          stage(stage) do
            send(stage)
            result if stage == :script
          end
        end

        def after_result
          self.if('$TRAVIS_TEST_RESULT = 0')  { run_stage(:after_success) } if config[:after_success]
          self.if('$TRAVIS_TEST_RESULT != 0') { run_stage(:after_failure) } if config[:after_failure]
        end

        def stage(stage = nil)
          sh.script &stacking {
            sh.options.update(timeout: data.timeouts[stage], assert: assert_stage?(stage))
            raw "echo travis_fold:start:#{stage}\r" if fold_stage?(stage)
            raw "travis_start #{stage}" if announce?(stage)
            yield
            raw "travis_finish #{stage} #{stage == :script ? '$TRAVIS_TEST_RESULT' : '$?'}" if announce?(stage)
            raw "echo travis_fold:end:#{stage}\r" if fold_stage?(stage)
          }
        end

        def fold_stage?(stage)
          not [:announce, :script, :after_result].include?(stage)
        end

        def assert_stage?(stage)
          [:setup, :before_install, :install, :before_script].include?(stage)
        end

        def result
          raw 'travis_result $?'
        end
      end
    end
  end
end
