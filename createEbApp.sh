#!/bin/bash
# By Dmitriy Kagarlickij
# dmitriy@kagarlickij.com

function setVariables {
    # Log files
    mainLog="/deploy-scripts/logs/createEbApp.log"
    tmpLog="/deploy-scripts/logs/createEbApp-tmp.log"

    # Dir with access keys
    secretFolder="/deploy-scripts/secret"

    # Errors counter
    errorsCounter="0"

    # ElasticBeanstalk tmp dir
    ebTmp="/deploy-scripts/tmp"

    # ElasticBeanstalk region
    ebRegion="us-east-1"

    # Application name
    appName="meteorapp"

    # Email for reports
    email="dmitriy@kagarlickij.com"
}

function clearLogs {
    # Echo to console
    echo ["$(date +"%d-%b %T %Z %z")"] "clearLogs function has been started"

    # Remove directory with old logs if it's present
    if [ ! -d /deploy-scripts/logs ]; then {
        mkdir /deploy-scripts/logs
        echo "Logs directory has been created"
    }
    fi

    # Remove old mainLog if it's present
    if [ -f "${mainLog}" ]; then {
        rm -f "${mainLog}"
        echo "Old mainLog has been deleted" >> "${mainLog}"
    }
    fi

    # Remove old tmpLog if it's present
    if [ -f "${tmpLog}" ]; then {
        rm -f "${tmpLog}"
        echo "Old tmpLog has been deleted" >> "${mainLog}"
    }
    fi

    # Start mainLog
    echo "-------" >> "${mainLog}"
    echo ["$(date +"%d-%b %T %Z %z")"] "createEbApp script has been started" >> "${mainLog}"

    # Echo to console
    echo ["$(date +"%d-%b %T %Z %z")"] "clearLogs function has been finished"
}

function installSoftware {
    # Function start time
    functionStartTime=$(date +"%s")

    # Add record to mainLog
    echo "-------" >> "${mainLog}"
    echo ["$(date +"%d-%b %T %Z %z")"] "installSoftware function has been started" >> "${mainLog}"

    # Update OS
    apt-get -qq update

    # Install basic software
    apt-get -qq install -y gcc g++ make curl python2.7 tree ssmtp
    ln -s /usr/bin/python2.7 /usr/bin/python

    # Check Docker
    which docker
    if [ $? -ne 0 ]; then {
        # Install Docker
        apt-get -qq update
        apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys 58118E89F3A912897C070ADBF76221572C52609D
        apt-add-repository 'deb https://apt.dockerproject.org/repo ubuntu-xenial main'
        apt-get -qq update
        apt-cache policy docker-engine
        apt-get -qq install -y docker-engine

        # Check installed Docker
        which docker
        if [ $? -ne 0 ]; then {
            errorsCounter="$[$errorsCounter +1]"
            echo ["$(date +"%d-%b %T %Z %z")"] "Docker has been installed with error" >> "${mainLog}"
        }
        else {
            echo ["$(date +"%d-%b %T %Z %z")"] "Docker has been installed successfully" >> "${mainLog}"
        }
        fi
    }
    else {
        echo ["$(date +"%d-%b %T %Z %z")"] "Docker has been already installed" >> "${mainLog}"
    }
    fi

    # Check Pip
    which pip
    if [ $? -ne 0 ]; then {
        # Install Pip
        curl -O https://bootstrap.pypa.io/get-pip.py
        python2.7 get-pip.py

        # Check installed Pip
        which pip
        if [ $? -ne 0 ]; then {
            errorsCounter="$[$errorsCounter +1]"
            echo ["$(date +"%d-%b %T %Z %z")"] "Pip has been installed with error" >> "${mainLog}"
        }
        else {
            echo ["$(date +"%d-%b %T %Z %z")"] "Pip has been installed successfully" >> "${mainLog}"
        }
        fi
    }
    else {
        echo ["$(date +"%d-%b %T %Z %z")"] "Pip has been already installed" >> "${mainLog}"
    }
    fi

    # Check EB CLI
    which eb
    if [ $? -ne 0 ]; then {
        # Install EB CLI
        pip install awsebcli

        # Check installed EB CLI
        which eb
        if [ $? -ne 0 ]; then {
            errorsCounter="$[$errorsCounter +1]"
            echo ["$(date +"%d-%b %T %Z %z")"] "EB CLI has been installed with error" >> "${mainLog}"
        }
        else {
            echo ["$(date +"%d-%b %T %Z %z")"] "EB CLI has been installed successfully" >> "${mainLog}"
        }
        fi
    }
    else {
        echo ["$(date +"%d-%b %T %Z %z")"] "EB CLI has been already installed " >> "${mainLog}"
    }
    fi

    # Check AWS CLI
    which aws
    if [ $? -ne 0 ]; then {
        # Install AWS CLI
        pip install awscli

        # Check installed AWS CLI
        which aws
        if [ $? -ne 0 ]; then {
            errorsCounter="$[$errorsCounter +1]"
            echo ["$(date +"%d-%b %T %Z %z")"] "AWS CLI has been installed with error" >> "${mainLog}"
        }
        else {
            echo ["$(date +"%d-%b %T %Z %z")"] "AWS CLI has been installed successfully" >> "${mainLog}"
        }
        fi
    }
    else {
        echo ["$(date +"%d-%b %T %Z %z")"] "AWS CLI has been already installed" >> "${mainLog}"
    }
    fi

    # Check Node
    which node
    if [ $? -ne 0 ]; then {
        # Install Node
        wget http://nodejs.org/dist/v0.10.41/node-v0.10.41.tar.gz
        tar -zxf node-* && cd node-*
        ./configure
        make
        make install
        
        # Check installed Node
        which node
        if [ $? -ne 0 ]; then {
            errorsCounter="$[$errorsCounter +1]"
            echo ["$(date +"%d-%b %T %Z %z")"] "Node has been installed with error" >> "${mainLog}"
        }
        else {
            echo ["$(date +"%d-%b %T %Z %z")"] "Node has been installed successfully" >> "${mainLog}"
        }
        fi
    }
    else {
        echo ["$(date +"%d-%b %T %Z %z")"] "Node has been already installed" >> "${mainLog}"
    }
    fi

    # Check Meteor
    which meteor
    if [ $? -ne 0 ]; then {
        # Install Meteor
        curl https://install.meteor.com/ | sh

        # Check installed Meteor
        which meteor
        if [ $? -ne 0 ]; then {
            errorsCounter="$[$errorsCounter +1]"
            echo ["$(date +"%d-%b %T %Z %z")"] "Meteor has been installed with error" >> "${mainLog}"
        }
        else {
            echo ["$(date +"%d-%b %T %Z %z")"] "Meteor has been installed successfully" >> "${mainLog}"
        }
        fi
    }
    else {
        echo ["$(date +"%d-%b %T %Z %z")"] "Meteor has been already installed" >> "${mainLog}"
    }
    fi

<<"COMMENT"
    # Update Npm
    npm install npm -g

    # Check updated Npm
    which npm
    if [ $? -ne 0 ]; then {
        errorsCounter="$[$errorsCounter +1]"
        echo ["$(date +"%d-%b %T %Z %z")"] "Npm has been updated with error" >> "${mainLog}"
    }
    else {
        echo ["$(date +"%d-%b %T %Z %z")"] "Npm has been updated successfully" >> "${mainLog}"
    }
    fi
COMMENT

    # Cleanup
    rm -rf /deploy-scripts/node-*
    rm -f /deploy-scripts/get-pip.py
    rm -f /deploy-scripts/node-*
    apt-get -qq update
    apt-get -qq autoclean

    # Function end time
    functionEndTime=$(date +"%s")

    # Function execution time
    runtime=$((functionEndTime-functionStartTime))

    # Check function results
    if [ "${errorsCounter}" -gt 0 ]; then {
        echo ["$(date +"%d-%b %T %Z %z")"] "installSoftware function has been finished with status: ERROR in "${runtime}" sec" >> "${mainLog}"
        endMain
    }
    else {
        echo ["$(date +"%d-%b %T %Z %z")"] "installSoftware function has been finished with status: SUCCESS in "${runtime}" sec" >> "${mainLog}"
        echo "-------" >> "${mainLog}"
    }
    fi
}

function setLogins {
    # Function start time
    functionStartTime=$(date +"%s")

    # Add record to mainLog
    echo "-------" >> "${mainLog}"
    echo ["$(date +"%d-%b %T %Z %z")"] "setLogins function has been started" >> "${mainLog}"


    # Install AWS key
    if [ -d ~/.aws ]; then {
        rm -rf ~/.aws
    }
    fi

    mkdir /root/.aws
    cp "${secretFolder}""/aws/config" /root/.aws/config
    cp "${secretFolder}""/aws/credentials" /root/.aws/credentials

    # Install Docker key
    if [ ! -d ~/.docker ]; then {
        mkdir ~/.docker
    }
    fi

    if [ -f ~/.docker/config.json ]; then {
        diff "${secretFolder}""/config.json" ~/.docker/config.json > "${tmpLog}"
        if [[ $(find "${tmpLog}" -type f -size +1c) ]]; then {
            rm -f ~/.docker/config.json
            cp "${secretFolder}""/config.json" ~/.docker
            echo ["$(date +"%d-%b %T %Z %z")"] "Docker login has been replaced" >> "${mainLog}"
        }
        fi
    }
    else {
        cp "${secretFolder}""/config.json" ~/.docker
        echo ["$(date +"%d-%b %T %Z %z")"] "Docker login has been copied" >> "${mainLog}"
    }
    fi

    # Check Docker key
    diff "${secretFolder}""/config.json" ~/.docker/config.json > "${tmpLog}"
    if [[ $(find "${tmpLog}" -type f -size +1c) ]]; then {
        errorsCounter="$[$errorsCounter +1]"
        echo ["$(date +"%d-%b %T %Z %z")"] "Docker login has been checked with error" >> "${mainLog}"
    }
    else {
        echo ["$(date +"%d-%b %T %Z %z")"] "Docker login has been checked successfully" >> "${mainLog}"
    }
    fi

    # Install GitHub deploy key
    if [ -f ~/.ssh/GitHub_meteor_deploy ]; then {
        diff "${secretFolder}""/GitHub_meteor_deploy" ~/.ssh/GitHub_meteor_deploy > "${tmpLog}"
        if [[ $(find "${tmpLog}" -type f -size +1c) ]]; then {
            rm -f ~/.ssh/GitHub_meteor_deploy
            cp "${secretFolder}""/GitHub_meteor_deploy" ~/.ssh
            chmod 600 ~/.ssh/GitHub_meteor_deploy
            echo ["$(date +"%d-%b %T %Z %z")"] "GitHub login has been replaced" >> "${mainLog}"
        }
        fi
    }
    else {
        cp "${secretFolder}""/GitHub_meteor_deploy" ~/.ssh
        chmod 600 ~/.ssh/GitHub_meteor_deploy
        echo ["$(date +"%d-%b %T %Z %z")"] "GitHub login has been copied" >> "${mainLog}"
    }
    fi

    # Check GitHub deploy key
    diff "${secretFolder}""/GitHub_meteor_deploy" ~/.ssh/GitHub_meteor_deploy > "${tmpLog}"
    if [[ $(find "${tmpLog}" -type f -size +1c) ]]; then {
        errorsCounter="$[$errorsCounter +1]"
        echo ["$(date +"%d-%b %T %Z %z")"] "GitHub login has been checked with error" >> "${mainLog}"
    }
    else {
        echo ["$(date +"%d-%b %T %Z %z")"] "GitHub login has been checked successfully" >> "${mainLog}"
    }
    fi

    # Set local Git config
    if [ -f ~/.ssh/config ]; then {
        diff "${secretFolder}""/config" ~/.ssh/config > "${tmpLog}"
        if [[ $(find "${tmpLog}" -type f -size +1c) ]]; then {
            rm -f ~/.ssh/config
            cp "${secretFolder}""/config" ~/.ssh
            chmod 600 ~/.ssh/config
            echo ["$(date +"%d-%b %T %Z %z")"] "Local Git config has been replaced" >> "${mainLog}"
        }
        fi
    }
    else {
        cp "${secretFolder}""/config" ~/.ssh
        chmod 600 ~/.ssh/config
        echo ["$(date +"%d-%b %T %Z %z")"] "Local Git config has been copied" >> "${mainLog}"
    }
    fi

    # Check local Git config
    diff "${secretFolder}""/config" ~/.ssh/config > "${tmpLog}"
    if [[ $(find "${tmpLog}" -type f -size +1c) ]]; then {
        errorsCounter="$[$errorsCounter +1]"
        echo ["$(date +"%d-%b %T %Z %z")"] "Local Git config has been checked with error" >> "${mainLog}"
    }
    else {
        echo ["$(date +"%d-%b %T %Z %z")"] "Local Git config has been checked successfully" >> "${mainLog}"
    }
    fi

    # Install SSMTP key
    if [ -f /etc/ssmtp/ssmtp.conf ]; then {
        diff "${secretFolder}""/ssmtp.conf" /etc/ssmtp/ssmtp.conf > "${tmpLog}"
        if [[ $(find "${tmpLog}" -type f -size +1c) ]]; then {
            rm -f /etc/ssmtp/ssmtp.conf
            cp "${secretFolder}""/ssmtp.conf" /etc/ssmtp
            echo ["$(date +"%d-%b %T %Z %z")"] "SSMTP config has been replaced" >> "${mainLog}"
        }
        fi
    }
    else {
        cp "${secretFolder}""/ssmtp.conf" /etc/ssmtp
        echo ["$(date +"%d-%b %T %Z %z")"] "SSMTP config has been copied" >> "${mainLog}"
    }
    fi

    # Check SSMTP key
    diff "${secretFolder}""/ssmtp.conf" /etc/ssmtp/ssmtp.conf > "${tmpLog}"
    if [[ $(find "${tmpLog}" -type f -size +1c) ]]; then {
        errorsCounter="$[$errorsCounter +1]"
        echo ["$(date +"%d-%b %T %Z %z")"] "SSMTP config has been checked with error" >> "${mainLog}"
    }
    else {
        echo ["$(date +"%d-%b %T %Z %z")"] "SSMTP config has been checked successfully" >> "${mainLog}"
    }
    fi

    # Function end time
    functionEndTime=$(date +"%s")

    # Function execution time
    runtime=$((functionEndTime-functionStartTime))

    # Check function results
    if [ "${errorsCounter}" -gt 0 ]; then {
        echo ["$(date +"%d-%b %T %Z %z")"] "setLogins function has been finished with status: ERROR in "${runtime}" sec" >> "${mainLog}"
        endMain
    }
    else {
        echo ["$(date +"%d-%b %T %Z %z")"] "setLogins function has been finished with status: SUCCESS in "${runtime}" sec" >> "${mainLog}"
        echo "-------" >> "${mainLog}"
    }
    fi
}

function sendEmail {
    # Add record to mainLog
    echo "-------" >> "${mainLog}"
    echo ["$(date +"%d-%b %T %Z %z")"] "sendEmail function has been started" >> "${mainLog}"

    # Set email subject
    grep "all functions" "${mainLog}" > "${tmpLog}"
    grep -q "SUCCESS" "${tmpLog}"
    if [ $? -ne 0 ]; then {
            subject="createEbApp has been finished with status: ERROR"
    }
    else {
            subject="createEbApp has been finished with status: SUCCESS"
    }
    fi

    # Set mail content fron mainLog
    mainLogContent="$(cat "${mainLog}")"

# Run ssmtp to send mail
ssmtp "${email}" << EOF
From: Build machine <"${email}">
To: "${email}"
Subject: "${subject}"
${mainLogContent}
EOF

    # Echo to console
    echo ["$(date +"%d-%b %T %Z %z")"] "sendEmail function has been finished"
}

function endMain {
    # Function end time
    functionEndTimeMain=$(date +"%s")

    # Function execution time
    runtime=$((functionEndTimeMain-functionStartTimeMain))

    echo "-------" >> "${mainLog}"
    echo ["$(date +"%d-%b %T %Z %z")"] "ERROR: last function" >> "${mainLog}"
    echo "Previous functions have been executed in" "${runtime}" "seconds" >> "${mainLog}"
    echo "-------" >> "${mainLog}"

    sendEmail
    exit
}

function createEbApp {
    # Function start time
    functionStartTime=$(date +"%s")

    # Add record to mainLog
    echo "-------" >> "${mainLog}"
    echo ["$(date +"%d-%b %T %Z %z")"] "createEbApp function has been started" >> "${mainLog}"

    # Remove old and create new ElasticBeanstalk tmp dir
    if [ -d "${ebTmp}" ]; then {
        rm -rf "${ebTmp}"
        mkdir "${ebTmp}"
    }
    else {
        mkdir "${ebTmp}"
    }
    fi

    # Create Eb Application
    cd "${ebTmp}" && eb init "${appName}" --region "${ebRegion}" --platform "64bit Amazon Linux 2017.03 v2.7.3 running Docker 17.03.1-ce" --verbose > "${tmpLog}"

    # Function end time
    functionEndTime=$(date +"%s")

    # Function execution time
    runtime=$((functionEndTime-functionStartTime))

    grep -q "Application meteorapp has been created" ""${tmpLog}""
    if [ $? -ne 0 ]; then {
        errorsCounter="$[$errorsCounter +1]"
        echo ["$(date +"%d-%b %T %Z %z")"] "ElasticBeanstalk app has been created successfully" >> "${mainLog}"
    }
    else {
        echo ["$(date +"%d-%b %T %Z %z")"] "ElasticBeanstalk app has been created successfully" >> "${mainLog}"
    }
    fi

    # Check function results
    if [ "${errorsCounter}" -gt 0 ]; then {
        echo ["$(date +"%d-%b %T %Z %z")"] "createEbApp function has been finished with status: ERROR in "${runtime}" sec" >> "${mainLog}"
        endMain
    }
    else {
        echo ["$(date +"%d-%b %T %Z %z")"] "createEbApp function has been finished with status: SUCCESS in "${runtime}" sec" >> "${mainLog}"
        echo "-------" >> "${mainLog}"
    }
    fi
}

function main {
    # Function start time
    functionStartTimeMain=$(date +"%s")

    setVariables
    clearLogs
    installSoftware
    setLogins
    createEbApp


    # Function end time
    functionEndTimeMain=$(date +"%s")

    # Function execution time
    runtime=$((functionEndTimeMain-functionStartTimeMain))
    echo "-------" >> "${mainLog}"
    echo ["$(date +"%d-%b %T %Z %z")"] "SUCCESS: all functions" >> "${mainLog}"
    echo "All functions have been executed in" "${runtime}" "seconds" >> "${mainLog}"
    echo "-------" >> "${mainLog}"

    sendEmail
}

main
