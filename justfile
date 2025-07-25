fuzz:
    medusa fuzz

call-trace:
    #!/bin/sh
    rm call-trace.txt
    LATEST_MEDUSA_LOG=$(ls -1dt corpus/logs/* | head -n 1)
    cp "$LATEST_MEDUSA_LOG" call-trace.txt
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
    rm repomix-output.xml
    npx repomix . --style xml

clean:
    rm -rf slither_results.json corpus crytic-export cache out
