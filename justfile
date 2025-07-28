fuzz:
    medusa fuzz

call-trace:
    #!/bin/sh
    rm call-trace.txt
    LATEST_MEDUSA_LOG=$(ls -1dt corpus/logs/* | head -n 1)
    cp "$LATEST_MEDUSA_LOG" call-trace-raw.txt
    sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[mGK]//g" call-trace-raw.txt > call-trace.txt
    rm call-trace-raw.txt
    echo "$LATEST_MEDUSA_LOG > call-trace.txt"

debug:
    #!/bin/sh
    LATEST_MEDUSA_LOG=$(ls -1dt corpus/logs/* | head -n 1)
    echo "$LATEST_MEDUSA_LOG"
    cat "$LATEST_MEDUSA_LOG" | grep -e "‣ *"

coverage:
    open corpus/coverage/coverage_report.html

revert:
    open corpus/coverage/revert_report.html

repomix:
    rm -f repomix-output.xml
    npx repomix . --style xml --ignore "lib/**"

clean:
    rm -rf slither_results.json corpus crytic-export cache out
