#!/bin/bash
# By Dmitriy Kagarlickij
# dmitriy@kagarlickij.com
# http://kagarlickij.com

# Set environmental variable
PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games"

# Get positional parameter "action"
action=$1

# Get positional parameter "environment"
env=$2

# Set general variables

# Timezones
timeUTC="$(TZ=UTC date)"
timeNY="$(TZ=America/New_York date)"
timeKiev="$(TZ=Europe/Kiev date)"

# Errors counter
errorsCounter="0"

# Dir with scripts
scriptsDir="/deploy-scripts"

# Script name
scriptName="meteorapp.sh"

# Application name
appName="meteorapp"

# Log files
mainLog=${scriptsDir}"/logs/"${action}"-"${env}"App.log"
tmpLog=${scriptsDir}"/logs/"${action}"-"${env}App"-tmp.log"

# Cronfiles
cronfileDev="/etc/cron.d/gitPullDev"
cronfileStg="/etc/cron.d/gitPullStg"

# Dir with sources
sources="/app/sources/${env}"

# Dir with builds
builds="/app/builds/${env}"

# Dir with access keys
secretFolder=${scriptsDir}"/secret"

# GitHub repo
gitRepo="https://github.com/kagarlickijd/${appName}.git"

# DockerHub repo
dockerRepo="kagarlickij/${appName}"

# ElasticBeanstalk CNAME
ebCname="${appName}-${env}"

# ElasticBeanstalk timeout
ebTimeout="60"

# ElasticBeanstalk region
ebRegion="us-east-1"

# S3 Bucket & key for Docker
s3Bucket="dockerhubkey"
s3Key="dockerconfig"

# Email for reports
email="dmitriy@kagarlickij.com"

# Set environment specific variables depending on environment
if [ "${env}" == "dev" ]; then {
    # Dir with scripts
    scriptsDir="/deploy-scripts"

    # Git branch
    gitBranch="dev"

    # Mongo URL
    mongoUrl="$(cat ${scriptsDir}/secret/mongoConnStr)"

    # Root URL
    rootUrl="ROOT_URL=http://dev.${appName}.kagarlickij.com"

    # Required site title
    siteTitle="DEV SITE"

    # Required site status code
    siteStatusCode="200"
}
elif [ "${env}" == "stg" ]; then {
    # Dir with scripts
    scriptsDir="/deploy-scripts"

    # Git branch
    gitBranch="master"

    # Mongo URL
    mongoUrl="$(cat ${scriptsDir}/secret/mongoConnStr)"

    # Root URL
    rootUrl="ROOT_URL=http://${appName}.kagarlickij.com"

    # Required site title
    siteTitle="Leaderboard"

    # Required site status code
    siteStatusCode="200"
}
elif [ "${env}" == "prod" ]; then {
    # Dir with scripts
    scriptsDir="/deploy-scripts"

    # Git branch
    gitBranch="master"

    # Mongo URL
    mongoUrl="$(cat ${scriptsDir}/secret/mongoConnStr)"

    # Root URL
    rootUrl="ROOT_URL=http://${appName}.kagarlickij.com"

    # Required site title
    siteTitle="Leaderboard"

    # Required site status code
    siteStatusCode="200"
}
else {
    # Exit in case of unknown environment
    echo "Unknown environment. Script stopped."
    exit
}
fi

function clearLogs {
    # Echo to console
    echo ["$(date +"%d-%b %T %Z %z")"] "clearLogs function has been started"

    # Remove directory with old logs if it's present
    if [ ! -d ${scriptsDir}/logs ]; then {
        mkdir ${scriptsDir}/logs
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
    echo ["$(date +"%d-%b %T %Z %z")"] "Working on ""${action}"" action with ""${env}" "environment" >> "${mainLog}"
    echo ["$(date +"%d-%b %T %Z %z")"] ""${action}"App script has been started" >> "${mainLog}"

    # Echo to console
    echo ["$(date +"%d-%b %T %Z %z")"] "clearLogs function has been finished"
}

function sendEmail {
    # Add record to mainLog
    echo "-------" >> "${mainLog}"
    echo ["$(date +"%d-%b %T %Z %z")"] "sendEmail function has been started" >> "${mainLog}"

    # Set email subject
    grep "all functions" "${mainLog}" > "${tmpLog}"
    grep -q "SUCCESS" "${tmpLog}"
    if [ $? -ne 0 ]; then {
            subject=""${action}"App-"${env}" has been finished with status: ERROR"
    }
    else {
            subject=""${action}"App-"${env}" has been finished with status: SUCCESS"
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

function deleteDockerContainers {
    # Function start time
    functionStartTime=$(date +"%s")

    # Add record to mainLog
    echo "-------" >> "${mainLog}"
    echo ["$(date +"%d-%b %T %Z %z")"] "Working on ""${action}"" action with ""${env}" "environment" >> "${mainLog}"
    echo ["$(date +"%d-%b %T %Z %z")"] "deleteDockerContainers function has been started" >> "${mainLog}"

    # Stop running Docker containers if they're present
    docker ps > "${tmpLog}"
    grep -q "${env}" "${tmpLog}"

    if [ $? -eq 0 ]; then {
        docker stop --time=10 "${env}"

        docker ps > "${tmpLog}"
        grep -q "${env}" "${tmpLog}"
        if [ $? -eq 0 ]; then {
            errorsCounter="$[$errorsCounter +1]"
            echo ["$(date +"%d-%b %T %Z %z")"] "Docker containers have been stopped with error" >> "${mainLog}"
        }
        else {
            echo ["$(date +"%d-%b %T %Z %z")"] "Docker containers have been stopped successfully" >> "${mainLog}"
        }
        fi
    }
    else {
        echo ["$(date +"%d-%b %T %Z %z")"] "Docker containers have not been started" >> "${mainLog}"
    }
    fi

    # Delete Docker containers if they're present
    docker ps -a > "${tmpLog}"
    grep -q "${env}" "${tmpLog}"

    if [ $? -eq 0 ]; then {
        docker rm "${env}" &>/dev/null

        docker ps -a > "${tmpLog}"
        grep -q "${env}" "${tmpLog}"
        if [ $? -eq 0 ]; then {
            docker rm -f "${env}" &>/dev/null

            docker ps -a > "${tmpLog}"
            grep -q "${env}" "${tmpLog}"
            if [ $? -eq 0 ]; then {
                errorsCounter="$[$errorsCounter +1]"
                echo ["$(date +"%d-%b %T %Z %z")"] "Docker containers have been deleted with error" >> "${mainLog}"
            }
            else {
                echo ["$(date +"%d-%b %T %Z %z")"] "Docker containes have been force deleted successfully" >> "${mainLog}"
            }
            fi
        }
        else {
            echo ["$(date +"%d-%b %T %Z %z")"] "Docker containers have been deleted successfully" >> "${mainLog}"
        }
        fi
    }
    else {
        echo ["$(date +"%d-%b %T %Z %z")"] "Docker containers have not been found" >> "${mainLog}"
    }
    fi

    # Function end time
    functionEndTime=$(date +"%s")

    # Function execution time
    runtime=$((functionEndTime-functionStartTime))

    # Check function results
    if [ "${errorsCounter}" -gt 0 ]; then {
        echo ["$(date +"%d-%b %T %Z %z")"] "deleteDockerContainers function has been finished with status: ERROR in "${runtime}" sec" >> "${mainLog}"
        endMain
    }
    else {
        echo ["$(date +"%d-%b %T %Z %z")"] "deleteDockerContainers function has been finished with status: SUCCESS in "${runtime}" sec" >> "${mainLog}"
        echo "-------" >> "${mainLog}"
    }
    fi
}

function deleteDockerImages {
    # Function start time
    functionStartTime=$(date +"%s")

    # Add record to mainLog
    echo "-------" >> "${mainLog}"
    echo ["$(date +"%d-%b %T %Z %z")"] "Working on ""${action}"" action with ""${env}" "environment" >> "${mainLog}"
    echo ["$(date +"%d-%b %T %Z %z")"] "deleteDockerImages function has been started" >> "${mainLog}"

    # Delete Docker images if they're present
    docker images > "${tmpLog}"
    grep -q "${env}" "${tmpLog}"
    if [ $? -eq 0 ]; then {
        docker rmi "${dockerRepo}":"${env}" &>/dev/null

        docker images > "${tmpLog}"
        grep -q "${env}" "${tmpLog}"
        if [ $? -eq 0 ]; then {
            docker rmi -f "${dockerRepo}":"${env}" &>/dev/null

            docker images > "${tmpLog}"
            grep -q "${env}" "${tmpLog}"
            if [ $? -eq 0  ]; then {
                errorsCounter="$[$errorsCounter +1]"
                echo ["$(date +"%d-%b %T %Z %z")"] "Docker images have been deleted with error" >> "${mainLog}"
            }
            else {
                echo ["$(date +"%d-%b %T %Z %z")"] "Docker images have been force deleted successfully" >> "${mainLog}"
            }
            fi
        }
        else {
            echo ["$(date +"%d-%b %T %Z %z")"] "Docker images have been deleted successfully" >> "${mainLog}"
        }
        fi
    }
    else {
        echo ["$(date +"%d-%b %T %Z %z")"] "No Docker images have been found" >> "${mainLog}"
    }
    fi

    # Function end time
    functionEndTime=$(date +"%s")

    # Function execution time
    runtime=$((functionEndTime-functionStartTime))

    # Check function results
    if [ "${errorsCounter}" -gt 0 ]; then {
        echo ["$(date +"%d-%b %T %Z %z")"] "deleteDockerImages function has been finished with status: ERROR in "${runtime}" sec" >> "${mainLog}"
        endMain
    }
    else {
        echo ["$(date +"%d-%b %T %Z %z")"] "deleteDockerImages function has been finished with status: SUCCESS in "${runtime}" sec" >> "${mainLog}"
        echo "-------" >> "${mainLog}"
    }
    fi
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

function installSoftware {
    # Function start time
    functionStartTime=$(date +"%s")

    # Add record to mainLog
    echo "-------" >> "${mainLog}"
    echo ["$(date +"%d-%b %T %Z %z")"] "Working on ""${action}"" action with ""${env}" "environment" >> "${mainLog}"
    echo ["$(date +"%d-%b %T %Z %z")"] "installSoftware function has been started" >> "${mainLog}"

    # Update OS
    apt-get -qq update

    # Install basic software
    apt-get -qq install -y gcc g++ make curl python2.7 tree ssmtp
    ln -s /usr/bin/python2.7 /usr/bin/python

    # Check Docker
    which docker &>/dev/null
    if [ $? -ne 0 ]; then {
        # Install Docker
        apt-get -qq update
        apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys 58118E89F3A912897C070ADBF76221572C52609D
        apt-add-repository 'deb https://apt.dockerproject.org/repo ubuntu-xenial main'
        apt-get -qq update
        apt-cache policy docker-engine
        apt-get -qq install -y docker-engine

        # Check installed Docker
        which docker &>/dev/null
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
    which pip &>/dev/null
    if [ $? -ne 0 ]; then {
        # Install Pip
        curl -O https://bootstrap.pypa.io/get-pip.py
        python2.7 get-pip.py

        # Check installed Pip
        which pip &>/dev/null
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
    which eb &>/dev/null
    if [ $? -ne 0 ]; then {
        # Install EB CLI
        pip install awsebcli

        # Check installed EB CLI
        which eb &>/dev/null
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
    which aws &>/dev/null
    if [ $? -ne 0 ]; then {
        # Install AWS CLI
        pip install awscli

        # Check installed AWS CLI
        which aws &>/dev/null
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
    which node &>/dev/null
    if [ $? -ne 0 ]; then {
        # Install Node
        wget http://nodejs.org/dist/v0.10.41/node-v0.10.41.tar.gz
        tar -zxf node-* && cd node-*
        ./configure
        make
        make install

        # Check installed Node
        which node &>/dev/null
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
    which meteor &>/dev/null
    if [ $? -ne 0 ]; then {
        # Install Meteor
        curl https://install.meteor.com/ | sh

        # Check installed Meteor
        which meteor &>/dev/null
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
    npm install npm -g &>/dev/null

    # Check updated Npm
    which npm &>/dev/null
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
    rm -rf ${scriptsDir}/node-*
    rm -f ${scriptsDir}/get-pip.py
    rm -f ${scriptsDir}/node-*
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
    echo ["$(date +"%d-%b %T %Z %z")"] "Working on ""${action}"" action with ""${env}" "environment" >> "${mainLog}"
    echo ["$(date +"%d-%b %T %Z %z")"] "setLogins function has been started" >> "${mainLog}"

    # Install AWS key
    if [ -d /root/.aws ]; then {
        rm -rf /root/.aws
    }
    fi

    mkdir /root/.aws
    cp "${secretFolder}""/aws/config" /root/.aws
    cp "${secretFolder}""/aws/credentials" /root/.aws

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

function cloneGit {
    # Function start time
    functionStartTime=$(date +"%s")

    # Add record to mainLog
    echo "-------" >> "${mainLog}"
    echo ["$(date +"%d-%b %T %Z %z")"] "Working on ""${action}"" action with ""${env}" "environment" >> "${mainLog}"
    echo ["$(date +"%d-%b %T %Z %z")"] "cloneGit function has been started" >> "${mainLog}"

    # Delete old folder with sources if it's present
    if [ -d "${sources}" ]; then {
        rm -rf "${sources}"
    }
    fi

    # Create folder with sources
    echo "sources =" "${sources}"
    mkdir --parents "${sources}"

    # Clone repo branch from GitHub
    git clone "${gitRepo}" "${sources}" -b "${gitBranch}" --single-branch --quiet

    # Check branch status
    git -C "${sources}" status > "${tmpLog}"
    grep -q "Your branch is up-to-date" ""${tmpLog}""
    if [ $? -ne 1 ]; then {
        echo ["$(date +"%d-%b %T %Z %z")"] "Branch has been cloned successfully" >> "${mainLog}"
    }
    else {
        errorsCounter="$[$errorsCounter +1]"
        echo ["$(date +"%d-%b %T %Z %z")"] "Branch has been cloned with error" >> "${mainLog}"
    }
    fi

    # Function end time
    functionEndTime=$(date +"%s")

    # Function execution time
    runtime=$((functionEndTime-functionStartTime))

    # Check function results
    if [ "${errorsCounter}" -gt 0 ]; then {
        echo ["$(date +"%d-%b %T %Z %z")"] "cloneGit function has been finished with status: ERROR in "${runtime}" sec" >> "${mainLog}"
        endMain
    }
    else {
        echo ["$(date +"%d-%b %T %Z %z")"] "cloneGit function has been finished with status: SUCCESS in "${runtime}" sec" >> "${mainLog}"
        echo "-------" >> "${mainLog}"
    }
    fi
}

function checkGitStatus {
    # Function start time
    functionStartTime=$(date +"%s")

    # Add record to mainLog
    echo "-------" >> "${mainLog}"
    echo ["$(date +"%d-%b %T %Z %z")"] "${env}" "environment" >> "${mainLog}"
    echo ["$(date +"%d-%b %T %Z %z")"] "checkGitStatus function has been started" >> "${mainLog}"

    # Attach git HEAD
    git -C "${sources}" status > "${tmpLog}"
    grep -q "HEAD detached" "${tmpLog}"
    if [ $? -ne 0 ]; then {
            echo ["$(date +"%d-%b %T %Z %z")"] "Git status has been checked successfully" >> "${mainLog}"
    }
    else {
            git -C "${sources}" checkout "${gitBranch}"
            git -C "${sources}" status > "${tmpLog}"
            grep -q "HEAD detached" "${tmpLog}"
            if [ $? -ne 0 ]; then {
                echo ["$(date +"%d-%b %T %Z %z")"] "Git status has been set successfully" >> "${mainLog}"
            }
            else {
                errorsCounter="$[$errorsCounter +1]"
                echo ["$(date +"%d-%b %T %Z %z")"] "Git status has been set with error" >> "${mainLog}"
            }
            fi
    }
    fi

    # Function end time
    functionEndTime=$(date +"%s")

    # Function execution time
    runtime=$((functionEndTime-functionStartTime))

    # Check function results
    if [ "${errorsCounter}" -gt 0 ]; then {
        echo ["$(date +"%d-%b %T %Z %z")"] "checkGitStatus function has been finished with status: ERROR in "${runtime}" sec" >> "${mainLog}"
        endMain
    }
    else {
        echo ["$(date +"%d-%b %T %Z %z")"] "checkGitStatus function has been finished with status: SUCCESS in "${runtime}" sec" >> "${mainLog}"
        echo "-------" >> "${mainLog}"
    }
    fi
}

function rewindGit {
    # Function start time
    functionStartTime=$(date +"%s")

    # Add record to mainLog
    echo "-------" >> "${mainLog}"
    echo ["$(date +"%d-%b %T %Z %z")"] "Working on ""${action}"" action with ""${env}" "environment" >> "${mainLog}"
    echo ["$(date +"%d-%b %T %Z %z")"] "rewindGit function has been started" >> "${mainLog}"

    # Detach git HEAD
    git -C "${sources}" log --pretty=format:"%H" > "${tmpLog}"
    git -C "${sources}" checkout $(head -2 "${tmpLog}" | tail -1)

    # Check git HEAD
    git -C "${sources}" status > "${tmpLog}"
    grep -q "HEAD detached" "${tmpLog}"
    if [ $? -eq 0 ]; then {
            echo ["$(date +"%d-%b %T %Z %z")"] "Previous commit has been set successfully" >> "${mainLog}"
    }
    else {
            errorsCounter="$[$errorsCounter +1]"
            echo ["$(date +"%d-%b %T %Z %z")"] "Previous commit has been set with error" >> "${mainLog}"
    }
    fi

    # Function end time
    functionEndTime=$(date +"%s")

    # Function execution time
    runtime=$((functionEndTime-functionStartTime))

    # Check function results
    if [ "${errorsCounter}" -gt 0 ]; then {
        echo ["$(date +"%d-%b %T %Z %z")"] "rewindGit function has been finished with status: ERROR in "${runtime}" sec" >> "${mainLog}"
        endMain
    }
    else {
        echo ["$(date +"%d-%b %T %Z %z")"] "rewindGit function has been finished with status: SUCCESS in "${runtime}" sec" >> "${mainLog}"
        echo "-------" >> "${mainLog}"
    }
    fi
}

function setGitSchedule {
    # Function start time
    functionStartTime=$(date +"%s")

    # Add record to mainLog
    echo "-------" >> "${mainLog}"
    echo ["$(date +"%d-%b %T %Z %z")"] "Working on ""${action}"" action with ""${env}" "environment" >> "${mainLog}"
    echo ["$(date +"%d-%b %T %Z %z")"] "setGitSchedule function has been started" >> "${mainLog}"

    # Set git pull schedule depending on action
    if [ "${env}" == "dev" ] && [ "${action}" == "create" ]; then {
        echo "*/5 * * * * git -C ${sources} pull" > "${cronfileDev}"
        cat "${cronfileDev}" "${cronfileStg}" | crontab
        echo ["$(date +"%d-%b %T %Z %z")"] "Git pull schedule has been enabled for dev" >> "${mainLog}"
    }
    fi

    if [ "${env}" == "dev" ] && [ "${action}" == "deploy" ]; then {
        echo "*/5 * * * * git -C ${sources} pull" > "${cronfileDev}"
        cat "${cronfileDev}" "${cronfileStg}" | crontab
        echo ["$(date +"%d-%b %T %Z %z")"] "Git pull schedule has been enabled for dev" >> "${mainLog}"
    }
    fi

    if [ "${env}" == "dev" ] && [ "${action}" == "restore" ]; then {
        echo "# */5 * * * * git -C ${sources} pull" > "${cronfileDev}"
        cat "${cronfileDev}" "${cronfileStg}" | crontab
        echo ["$(date +"%d-%b %T %Z %z")"] "Git pull schedule has been disabled for dev" >> "${mainLog}"
    }
    fi

    if [ "${env}" == "stg" ] && [ "${action}" == "create" ]; then {
        echo "*/16 * * * * git -C ${sources} pull" > "${cronfileStg}"
        cat "${cronfileDev}" "${cronfileStg}" | crontab
        echo ["$(date +"%d-%b %T %Z %z")"] "Git pull schedule has been enabled for stg" >> "${mainLog}"
    }
    fi

    if [ "${env}" == "stg" ] && [ "${action}" == "deploy" ]; then {
        echo "*/16 * * * * git -C ${sources} pull" > "${cronfileStg}"
        cat "${cronfileDev}" "${cronfileStg}" | crontab
        echo ["$(date +"%d-%b %T %Z %z")"] "Git pull schedule has been enabled for stg" >> "${mainLog}"
    }
    fi

    if [ "${env}" == "stg" ] && [ "${action}" == "restore" ]; then {
        echo "# */16 * * * * git -C ${sources} pull" > "${cronfileStg}"
        cat "${cronfileDev}" "${cronfileStg}" | crontab
        echo ["$(date +"%d-%b %T %Z %z")"] "Git pull schedule has been disabled for stg" >> "${mainLog}"
    }
    fi

    # Check git pull schedule
    if [ "${env}" == "dev" ] || [ "${env}" == "stg" ]; then {
        grep -q "git -C ${sources} pull" "/var/spool/cron/crontabs/root"
        if [ $? -ne 0 ]; then {
            errorsCounter="$[$errorsCounter +1]"
            echo ["$(date +"%d-%b %T %Z %z")"] "Git pull schedule has been set with errors" | tee >> "${mainLog}"
        }
        else {
            echo ["$(date +"%d-%b %T %Z %z")"] "Git pull schedule has been set successfully" | tee >> "${mainLog}"
        }
        fi
        }
    fi

    # Function end time
    functionEndTime=$(date +"%s")

    # Function execution time
    runtime=$((functionEndTime-functionStartTime))

    # Check function results
    if [ "${errorsCounter}" -gt 0 ]; then {
        echo ["$(date +"%d-%b %T %Z %z")"] "setGitSchedule function has been finished with status: ERROR in "${runtime}" sec" >> "${mainLog}"
        endMain
    }
    else {
        echo ["$(date +"%d-%b %T %Z %z")"] "setGitSchedule function has been finished with status: SUCCESS in "${runtime}" sec" >> "${mainLog}"
        echo "-------" >> "${mainLog}"
    }
    fi
}

function buildApp {
    # Function start time
    functionStartTime=$(date +"%s")

    # Add record to mainLog
    echo "-------" >> "${mainLog}"
    echo ["$(date +"%d-%b %T %Z %z")"] "Working on ""${action}"" action with ""${env}" "environment" >> "${mainLog}"
    echo ["$(date +"%d-%b %T %Z %z")"] "buildApp function has been started" >> "${mainLog}"

    # Delete dir with old builds if it's present
    if [ -d "${builds}" ]; then {
        rm -rf "${builds}"
    }
    fi

    # Delete old dir with app builds
    rm -rf "${builds}"
    if [ ! -d "${builds}" ]; then {
        echo ["$(date +"%d-%b %T %Z %z")"] "Old directory for app builds has been deleted successfully" >> "${mainLog}"
    }
    else {
        errorsCounter="$[$errorsCounter +1]"
        echo ["$(date +"%d-%b %T %Z %z")"] "Old directory for app builds has been deleted with error" >> "${mainLog}"
    }
    fi

    # Create dir for app builds
    mkdir --parents "${builds}"

    # Check dir for app builds
    if [ ! -d "${builds}" ]; then {
        errorsCounter="$[$errorsCounter +1]"
        echo ["$(date +"%d-%b %T %Z %z")"] "Directory for app builds has been created with error" >> "${mainLog}"
    }
    else {
        echo ["$(date +"%d-%b %T %Z %z")"] "Directory for app builds has been deleted successfully" >> "${mainLog}"
    }
    fi

    # Build meteor app
    cd "${sources}" && meteor build --directory "${builds}" --allow-superuser
    cd "${builds}""/bundle/programs/server" && npm install --silent > "${tmpLog}"
    if [ ! -f "${builds}""/bundle/main.js" ]; then {
        errorsCounter="$[$errorsCounter +1]"
        echo ["$(date +"%d-%b %T %Z %z")"] "App has been built with errors" >> "${mainLog}"
    }
    else {
        echo ["$(date +"%d-%b %T %Z %z")"] "App has been built successfully" >> "${mainLog}"
    }
    fi

    # Function end time
    functionEndTime=$(date +"%s")

    # Function execution time
    runtime=$((functionEndTime-functionStartTime))

    # Check function results
    if [ "${errorsCounter}" -gt 0 ]; then {
        echo ["$(date +"%d-%b %T %Z %z")"] "buildApp function has been finished with status: ERROR in "${runtime}" sec" >> "${mainLog}"
        endMain
    }
    else {
        echo ["$(date +"%d-%b %T %Z %z")"] "buildApp function has been finished with status: SUCCESS in "${runtime}" sec" >> "${mainLog}"
        echo "-------" >> "${mainLog}"
    }
    fi
}

function runLocalApp {
    # Function start time
    functionStartTime=$(date +"%s")

    # Add record to mainLog
    echo "-------" >> "${mainLog}"
    echo ["$(date +"%d-%b %T %Z %z")"] "Working on ""${action}"" action with ""${env}" "environment" >> "${mainLog}"
    echo ["$(date +"%d-%b %T %Z %z")"] "runLocalApp function has been started" >> "${mainLog}"

    # Set MONGO_URL environment variable
    printenv | grep MONGO_URL > "${tmpLog}"
    grep -q "MONGO_URL" ""${tmpLog}""  
    if [ $? -eq 0 ]; then {
        export -n MONGO_URL
        export "${mongoUrl}"
        echo ["$(date +"%d-%b %T %Z %z")"] "MONGO URL has been already set" >> "${mainLog}"
    }
    else {
        export "${mongoUrl}"
        echo ["$(date +"%d-%b %T %Z %z")"] "MONGO URL has been set" >> "${mainLog}"
    }
    fi

    # Set ROOT_URL environment variable
    printenv | grep ROOT_URL > "${tmpLog}"
    grep -q "ROOT_URL" ""${tmpLog}""
    if [ $? -eq 0 ]; then {
        export -n ROOT_URL
        export "${rootUrl}"
        echo ["$(date +"%d-%b %T %Z %z")"] "ROOT URL has been already set" >> "${mainLog}"
    }
    else {
        export "${rootUrl}"
        echo ["$(date +"%d-%b %T %Z %z")"] "ROOT URL has been set" >> "${mainLog}"
    }
    fi

    # Stop node if it runs
    ps aux | grep node > "${tmpLog}"
    grep -q "node main.js" ""${tmpLog}""
    if [ $? -eq 0 ]; then {
        killall node
        echo ["$(date +"%d-%b %T %Z %z")"] "Node has been stopped" >> "${mainLog}"
    }
    fi

    # Run node app
    cd "${builds}""/bundle/" && PORT=3000 node main.js & sleep 10

    # Check node runs
    ps aux | grep node > "${tmpLog}"
    grep -q "node main.js" ""${tmpLog}""
    if [ $? -eq 0 ]; then {
        echo ["$(date +"%d-%b %T %Z %z")"] "Local version of app has been started successfully" >> "${mainLog}"
    }
    else {
        errorsCounter="$[$errorsCounter +1]"
        echo ["$(date +"%d-%b %T %Z %z")"] "Local version of app has been started with error" >> "${mainLog}"
    }
    fi

    # Function end time
    functionEndTime=$(date +"%s")

    # Function execution time
    runtime=$((functionEndTime-functionStartTime))

    # Check function results
    if [ "${errorsCounter}" -gt 0 ]; then {
        echo ["$(date +"%d-%b %T %Z %z")"] "runLocalApp function has been finished with status: ERROR in "${runtime}" sec" >> "${mainLog}"
        endMain
    }
    else {
    echo ["$(date +"%d-%b %T %Z %z")"] "runLocalApp function has been finished with status: SUCCESS in "${runtime}" sec" >> "${mainLog}"
        echo "-------" >> "${mainLog}"
    }
    fi
}

function stopLocalApp {
    # Function start time
    functionStartTime=$(date +"%s")

    # Add record to mainLog
    echo "-------" >> "${mainLog}"
    echo ["$(date +"%d-%b %T %Z %z")"] "Working on ""${action}"" action with ""${env}" "environment" >> "${mainLog}"
    echo ["$(date +"%d-%b %T %Z %z")"] "stopLocalApp function has been started" >> "${mainLog}"

    # Stop local version of app & cleanup local env
    killall node
    export -n ROOT_URL
    export -n MONGO_URL

    # Check node runs
    ps aux | grep node > "${tmpLog}"
    grep -q "node main.js" ""${tmpLog}""
    if [ $? -eq 0 ]; then {
        errorsCounter="$[$errorsCounter +1]"
        echo ["$(date +"%d-%b %T %Z %z")"] "Local version of app has been stopped with error" >> "${mainLog}"
    }
    else {
        echo ["$(date +"%d-%b %T %Z %z")"] "Local version of app has been started successfully" >> "${mainLog}"
    }
    fi

    # Function end time
    functionEndTime=$(date +"%s")

    # Function execution time
    runtime=$((functionEndTime-functionStartTime))

    # Check function results
    if [ "${errorsCounter}" -gt 0 ]; then {
        echo ["$(date +"%d-%b %T %Z %z")"] "stopLocalApp function has been finished with status: ERROR in "${runtime}" sec" >> "${mainLog}"
        endMain
    }
    else {
    echo ["$(date +"%d-%b %T %Z %z")"] "stopLocalApp function has been finished with status: SUCCESS in "${runtime}" sec" >> "${mainLog}"
        echo "-------" >> "${mainLog}"
    }
    fi
}

function checkLocalApp {
    # Function start time
    functionStartTime=$(date +"%s")

    # Add record to mainLog
    echo "-------" >> "${mainLog}"
    echo ["$(date +"%d-%b %T %Z %z")"] "Working on ""${action}"" action with ""${env}" "environment" >> "${mainLog}"
    echo ["$(date +"%d-%b %T %Z %z")"] "checkLocalApp function has been started" >> "${mainLog}"

    # Check site content
    curl http://localhost:3000 | grep title > "${tmpLog}"
    grep -q "${siteTitle}" ""${tmpLog}""
    if [ $? -eq 0 ]; then {
        echo ["$(date +"%d-%b %T %Z %z")"] "Content has been checked successfully" >> "${mainLog}"
    }
    else {
        echo ["$(date +"%d-%b %T %Z %z")"] "Content has been checked with error" >> "${mainLog}"
        errorsCounter="$[$errorsCounter +1]"
    }
    fi

    # Check site status code
    curl -I http://localhost:3000 | grep HTTP/1.1 > "${tmpLog}"
    grep -q "${siteStatusCode}" ""${tmpLog}""
    if [ $? -eq 0 ]; then {
        echo ["$(date +"%d-%b %T %Z %z")"] "Status code has been checked successfully" >> "${mainLog}"
    }
    else {
        errorsCounter="$[$errorsCounter +1]"
        echo ["$(date +"%d-%b %T %Z %z")"] "Status code has been checked with error" >> "${mainLog}"
    }
    fi

    # Function end time
    functionEndTime=$(date +"%s")

    # Function execution time
    runtime=$((functionEndTime-functionStartTime))

    # Check function results
    if [ "${errorsCounter}" -gt 0 ]; then {
        echo ["$(date +"%d-%b %T %Z %z")"] "checkLocalApp function has been finished with status: ERROR in "${runtime}" sec" >> "${mainLog}"
        endMain
    }
    else {
    echo ["$(date +"%d-%b %T %Z %z")"] "checkLocalApp function has been finished with status: SUCCESS in "${runtime}" sec" >> "${mainLog}"
        echo "-------" >> "${mainLog}"
    }
    fi
}

function checkEbApp {
    # Function start time
    functionStartTime=$(date +"%s")

    # Add record to mainLog
    echo "-------" >> "${mainLog}"
    echo ["$(date +"%d-%b %T %Z %z")"] "Working on ""${action}"" action with ""${env}" "environment" >> "${mainLog}"
    echo ["$(date +"%d-%b %T %Z %z")"] "checkEbApp function has been started" >> "${mainLog}"

    # Check site content
    curl "${ebCname}"".""${ebRegion}"".elasticbeanstalk.com" | grep title > "${tmpLog}"
    grep -q "${siteTitle}" "${tmpLog}"
    if [ $? -ne 0 ]; then {
        errorsCounter="$[$errorsCounter +1]"
        echo ["$(date +"%d-%b %T %Z %z")"] "Content has been checked with error" >> "${mainLog}"
    }
    else {
        echo ["$(date +"%d-%b %T %Z %z")"] "Content has been checked successfully" >> "${mainLog}"
    }
    fi

    # Check site status code
    curl -I "${ebCname}"".""${ebRegion}"".elasticbeanstalk.com" | grep HTTP/1.1 > "${tmpLog}"
    grep -q "${siteStatusCode}" "${tmpLog}"
    if [ $? -ne 0 ]; then {
        errorsCounter="$[$errorsCounter +1]"
        echo ["$(date +"%d-%b %T %Z %z")"] "Status code has been checked with error" >> "${mainLog}"
    }
    else {
        echo ["$(date +"%d-%b %T %Z %z")"] "Status code has been checked successfully" >> "${mainLog}"
    }
    fi

    # Function end time
    functionEndTime=$(date +"%s")

    # Function execution time
    runtime=$((functionEndTime-functionStartTime))

    # Check function results
    if [ "${errorsCounter}" -gt 0 ]; then {
        echo ["$(date +"%d-%b %T %Z %z")"] "checkEbApp function has been finished with status: ERROR in "${runtime}" sec" >> "${mainLog}"
        echo ["$(date +"%d-%b %T %Z %z")"] "restoreApp function has been initiated. Log will be send in separate email" >> "${mainLog}"
        ${scriptsDir}/${scriptName} restore "${env}"
        endMain
    }
    else {
    echo ["$(date +"%d-%b %T %Z %z")"] "checkEbApp function has been finished with status: SUCCESS in "${runtime}" sec" >> "${mainLog}"
        echo "-------" >> "${mainLog}"
    }
    fi
}

function createDockerfile {
    # Function start time
    functionStartTime=$(date +"%s")

    # Add record to mainLog
    echo "-------" >> "${mainLog}"
    echo ["$(date +"%d-%b %T %Z %z")"] "Working on ""${action}"" action with ""${env}" "environment" >> "${mainLog}"
    echo ["$(date +"%d-%b %T %Z %z")"] "createDockerfile function has been started" >> "${mainLog}"

    # Remove old Dockerfile if it's present
    if [ -f "${builds}""/bundle/Dockerfile" ]; then {
        rm -f "${builds}""/bundle/Dockerfile"
        echo ["$(date +"%d-%b %T %Z %z")"] "Old Dockerfile has been removed" >> "${mainLog}"
    }
    fi

    # Create Dockerfile
    cat >> "${builds}""/bundle/Dockerfile" << EOF
FROM node:0.10.41
MAINTAINER Dmitriy Kagarlickij <${email}>
ENV ${rootUrl}
ENV ${mongoUrl}
ADD . /${appName}/${env}
WORKDIR /${appName}/${env}
ENTRYPOINT PORT=3000 node main.js
EOF

    # Check Dockerfile
    if [ ! -f "${builds}""/bundle/Dockerfile" ]; then {
        errorsCounter="$[$errorsCounter +1]"
        echo ["$(date +"%d-%b %T %Z %z")"] "Dockerfile has been created with error" >> "${mainLog}"
    }
    else {
        echo ["$(date +"%d-%b %T %Z %z")"] "Dockerfile has been created successfully" >> "${mainLog}"
    }
    fi

    # Function end time
    functionEndTime=$(date +"%s")

    # Function execution time
    runtime=$((functionEndTime-functionStartTime))

    # Check function results
    if [ "${errorsCounter}" -gt 0 ]; then {
        echo ["$(date +"%d-%b %T %Z %z")"] "createDockerfile function has been finished with status: ERROR in "${runtime}" sec" >> "${mainLog}"
        endMain
    }
    else {
        echo ["$(date +"%d-%b %T %Z %z")"] "createDockerfile function has been finished with status: SUCCESS in "${runtime}" sec" >> "${mainLog}"
        echo "-------" >> "${mainLog}"
    }
    fi
}

function buildDockerImage {
    # Function start time
    functionStartTime=$(date +"%s")

    # Add record to mainLog
    echo "-------" >> "${mainLog}"
    echo ["$(date +"%d-%b %T %Z %z")"] "Working on ""${action}"" action with ""${env}" "environment" >> "${mainLog}"
    echo ["$(date +"%d-%b %T %Z %z")"] "buildDockerImage function has been started" >> "${mainLog}"

    # Build Docker image
    cd "${builds}""/bundle" && docker build -t "${dockerRepo}":"${env}" . > "${tmpLog}"

    # Check build
    grep -q "Successfully built" ""${tmpLog}""
    if [ $? -ne 0 ]; then {
        errorsCounter="$[$errorsCounter +1]"
        echo ["$(date +"%d-%b %T %Z %z")"] "Docker has been built with error" >> "${mainLog}"
    }
    else {
        echo ["$(date +"%d-%b %T %Z %z")"] "Docker has been built successfully" >> "${mainLog}"
    }
    fi

    # Function end time
    functionEndTime=$(date +"%s")

    # Function execution time
    runtime=$((functionEndTime-functionStartTime))

    # Check function results
    if [ "${errorsCounter}" -gt 0 ]; then {
        echo ["$(date +"%d-%b %T %Z %z")"] "buildDockerImage function has been finished with status: ERROR in "${runtime}" sec" >> "${mainLog}"
        endMain
    }
    else {
        echo ["$(date +"%d-%b %T %Z %z")"] "buildDockerImage function has been finished with status: SUCCESS in "${runtime}" sec" >> "${mainLog}"
        echo "-------" >> "${mainLog}"
    }
    fi
}

function runLocalDocker {
    # Function start time
    functionStartTime=$(date +"%s")

    # Add record to mainLog
    echo "-------" >> "${mainLog}"
    echo ["$(date +"%d-%b %T %Z %z")"] "Working on ""${action}"" action with ""${env}" "environment" >> "${mainLog}"
    echo ["$(date +"%d-%b %T %Z %z")"] "runLocalDocker function has been started" >> "${mainLog}"


    # Run Docker container
    docker run  --name "${env}" -d -p 3000:3000 "${dockerRepo}":"${env}" &
    sleep "10"

    # Check Docker container
    docker ps > "${tmpLog}"
    grep -q "${env}" "${tmpLog}"
    if [ $? -eq 0 ]; then {
        echo ["$(date +"%d-%b %T %Z %z")"] "Docker container has been started successfully" >> "${mainLog}"
    }
    else {
        errorsCounter="$[$errorsCounter +1]"
        echo ["$(date +"%d-%b %T %Z %z")"] "Docker container has been started with error" >> "${mainLog}"
    }
    fi

    # Function end time
    functionEndTime=$(date +"%s")

    # Function execution time
    runtime=$((functionEndTime-functionStartTime))

    # Check function results
    if [ "${errorsCounter}" -gt 0 ]; then {
        echo ["$(date +"%d-%b %T %Z %z")"] "runLocalDocker function has been finished with status: ERROR in "${runtime}" sec" >> "${mainLog}"
        endMain
    }
    else {
        echo ["$(date +"%d-%b %T %Z %z")"] "runLocalDocker function has been finished with status: SUCCESS in "${runtime}" sec" >> "${mainLog}"
        echo "-------" >> "${mainLog}"
    }
    fi
}

function pushDockerImage {
    # Function start time
    functionStartTime=$(date +"%s")

    # Add record to mainLog
    echo "-------" >> "${mainLog}"
    echo ["$(date +"%d-%b %T %Z %z")"] "Working on ""${action}"" action with ""${env}" "environment" >> "${mainLog}"
    echo ["$(date +"%d-%b %T %Z %z")"] "pushDockerImage function has been started" >> "${mainLog}"

    # Push docker image
    docker push "${dockerRepo}":"${env}" > "${tmpLog}"
    grep -q "digest" ""${tmpLog}""
    if [ $? -ne 0 ]; then {
        errorsCounter="$[$errorsCounter +1]"
        echo ["$(date +"%d-%b %T %Z %z")"] "Docker image has been pushed with error" >> "${mainLog}"
    }
    else {
        echo ["$(date +"%d-%b %T %Z %z")"] "Docker image has been pushed successfully" >> "${mainLog}"
    }
    fi

    # Function end time
    functionEndTime=$(date +"%s")

    # Function execution time
    runtime=$((functionEndTime-functionStartTime))

    # Check function results
    if [ "${errorsCounter}" -gt 0 ]; then {
        echo ["$(date +"%d-%b %T %Z %z")"] "pushDockerImage function has been finished with status: ERROR in "${runtime}" sec" >> "${mainLog}"
        endMain
    }
    else {
        echo ["$(date +"%d-%b %T %Z %z")"] "pushDockerImage function has been finished with status: SUCCESS in "${runtime}" sec" >> "${mainLog}"
        echo "-------" >> "${mainLog}"
    }
    fi
}

function createDockerrun {
    # Function start time
    functionStartTime=$(date +"%s")

    # Add record to mainLog
    echo "-------" >> "${mainLog}"
    echo ["$(date +"%d-%b %T %Z %z")"] "Working on ""${action}"" action with ""${env}" "environment" >> "${mainLog}"
    echo ["$(date +"%d-%b %T %Z %z")"] "createDockerrun function has been started" >> "${mainLog}"

    # Remove old Dockerrun file if it's present
    if [ -f ${scriptsDir}/eb/${env}/Dockerrun.aws.json ]; then {
        rm -f ${scriptsDir}/eb/${env}/Dockerrun.aws.json
        echo ["$(date +"%d-%b %T %Z %z")"] "Old Dockerrun file has been removed" >> "${mainLog}"
    }
    fi

    # Create Dockerrun file
    cat >> ${scriptsDir}/eb/${env}/Dockerrun.aws.json << EOF
    {
    "AWSEBDockerrunVersion": "1",
    "Image": {
        "Name": "${dockerRepo}:${env}"
    },
    "Authentication": {
        "Bucket": "${s3Bucket}",
        "Key": "${s3Key}"
    },
    "Ports": [
    {
        "ContainerPort": "3000"
    }
    ]
    }
EOF

    # Check Dockerrun file
    if [ ! -f ${scriptsDir}/eb/${env}/Dockerrun.aws.json ] ; then {
        errorsCounter="$[$errorsCounter +1]"
        echo ["$(date +"%d-%b %T %Z %z")"] "Dockerrun file has been created with error" >> "${mainLog}"
    }
    else {
        echo ["$(date +"%d-%b %T %Z %z")"] "Dockerrun file has been created successfully" >> "${mainLog}"
    }
    fi

    # Function end time
    functionEndTime=$(date +"%s")

    # Function execution time
    runtime=$((functionEndTime-functionStartTime))

    # Check function results
    if [ "${errorsCounter}" -gt 0 ]; then {
        echo ["$(date +"%d-%b %T %Z %z")"] "createDockerrun function has been finished with status: ERROR in "${runtime}" sec" >> "${mainLog}"
        endMain
    }
    else {
        echo ["$(date +"%d-%b %T %Z %z")"] "createDockerrun function has been finished with status: SUCCESS in "${runtime}" sec" >> "${mainLog}"
        echo "-------" >> "${mainLog}"
    }
    fi
}

function checkEbCnames {
    # Function start time
    functionStartTime=$(date +"%s")

    # Add record to mainLog
    echo "-------" >> "${mainLog}"
    echo ["$(date +"%d-%b %T %Z %z")"] "Working on ""${action}"" action with ""${env}" "environment" >> "${mainLog}"
    echo ["$(date +"%d-%b %T %Z %z")"] "checkEbCnames function has been started" >> "${mainLog}"

    # Check CNAME availability
    cd ${scriptsDir}/eb/${env} && aws elasticbeanstalk check-dns-availability --region "${ebRegion}" --cname-prefix "${ebCname}" > "${tmpLog}"
    grep -q "true" ""${tmpLog}""
    if [ $? -ne 0 ]; then {
        errorsCounter="$[$errorsCounter +1]"
        echo ["$(date +"%d-%b %T %Z %z")"] "Eb CNAME has been checked with error" >> "${mainLog}"
    }
    else {
        echo ["$(date +"%d-%b %T %Z %z")"] "Eb CNAME has been checked successfully" >> "${mainLog}"
    }
    fi

    # Function end time
    functionEndTime=$(date +"%s")

    # Function execution time
    runtime=$((functionEndTime-functionStartTime))

    # Check function results
    if [ "${errorsCounter}" -gt 0 ]; then {
        echo ["$(date +"%d-%b %T %Z %z")"] "checkEbCnames function has been finished with status: ERROR in "${runtime}" sec" >> "${mainLog}"
        endMain
    }
    else {
        echo ["$(date +"%d-%b %T %Z %z")"] "checkEbCnames function has been finished with status: SUCCESS in "${runtime}" sec" >> "${mainLog}"
        echo "-------" >> "${mainLog}"
    }
    fi
}

function initEbEnv {
    # Function start time
    functionStartTime=$(date +"%s")

    # Add record to mainLog
    echo "-------" >> "${mainLog}"
    echo ["$(date +"%d-%b %T %Z %z")"] "Working on ""${action}"" action with ""${env}" "environment" >> "${mainLog}"
    echo ["$(date +"%d-%b %T %Z %z")"] "initEbEnv function has been started" >> "${mainLog}"


    # Create .elasticbeanstalk dir
    if [ ! -d ${scriptsDir}/eb/${env}/.elasticbeanstalk ] ; then {
        mkdir ${scriptsDir}/eb/${env}/.elasticbeanstalk
        echo ["$(date +"%d-%b %T %Z %z")"] ".elasticbeanstalk dir has been created" >> "${mainLog}"
    }
    else {
        echo ["$(date +"%d-%b %T %Z %z")"] ".elasticbeanstalk dir has been already present" >> "${mainLog}"
    }
    fi

    # Delete old Eb initial config file
    if [ -f ${scriptsDir}/eb/${env}/.elasticbeanstalk/config.yml ] ; then {
        rm -f ${scriptsDir}/eb/${env}/.elasticbeanstalk/config.yml
        echo ["$(date +"%d-%b %T %Z %z")"] "Old Eb initial config file has been deleted" >> "${mainLog}"
    }
    else {
        echo ["$(date +"%d-%b %T %Z %z")"] "Old Eb initial config file has not been found" >> "${mainLog}"
    }
    fi

    # Create Eb initial config file
    cat >> ${scriptsDir}/eb/${env}/.elasticbeanstalk/config.yml << EOF
branch-defaults:
  default:
    environment: ${appName}-${env}
    group_suffix: null
global:
  application_name: ${appName}
  default_ec2_keyname: null
  default_platform: 64bit Amazon Linux 2017.03 v2.7.3 running Docker 17.03.1-ce
  default_region: ${ebRegion}
  profile: null
  sc: null

EOF

    # Check Eb initial config file
    if [ ! -f ${scriptsDir}/eb/${env}/.elasticbeanstalk/config.yml ] ; then {
        errorsCounter="$[$errorsCounter +1]"
        echo ["$(date +"%d-%b %T %Z %z")"] "Eb initial config file has been created with error" >> "${mainLog}"
    }
    else {
        echo ["$(date +"%d-%b %T %Z %z")"] "Eb initial config file has been created successfully" >> "${mainLog}"
    }
    fi

    # Function end time
    functionEndTime=$(date +"%s")

    # Function execution time
    runtime=$((functionEndTime-functionStartTime))

    # Check functions results
    if [ "${errorsCounter}" -gt 0 ]; then {
        echo ["$(date +"%d-%b %T %Z %z")"] "initEbEnv function has been finished with status: ERROR in "${runtime}" sec" >> "${mainLog}"
        endMain
    }
    else {
        echo ["$(date +"%d-%b %T %Z %z")"] "initEbEnv function has been finished with status: SUCCESS in "${runtime}" sec" >> "${mainLog}"
    }
    fi
}

function createEbEnv {
    # Function start time
    functionStartTime=$(date +"%s")

    # Add record to mainLog
    echo "-------" >> "${mainLog}"
    echo ["$(date +"%d-%b %T %Z %z")"] "Working on ""${action}"" action with ""${env}" "environment" >> "${mainLog}"
    echo ["$(date +"%d-%b %T %Z %z")"] "createEbEnv function has been started" >> "${mainLog}"

    # Create Eb environment
    cd ${scriptsDir}/eb/${env} && eb create "${ebCname}" --cname "${ebCname}" --timeout "${ebTimeout}"

    # Replace Eb environment configuration
    cd ${scriptsDir}/eb/${env} && eb config save "${ebCname}" --cfg ${appName}-${env}-config
    cp ${scriptsDir}/eb/${env}/${appName}-${env}-config.cfg.yml ${scriptsDir}/eb/${env}/.elasticbeanstalk/saved_configs/${appName}-${env}-config.cfg.yml

    # Check Eb environment configuration
    if [ ! -f ${scriptsDir}/eb/${env}/.elasticbeanstalk/saved_configs/${appName}-${env}-config.cfg.yml ] ; then {
        errorsCounter="$[$errorsCounter +1]"
        echo ["$(date +"%d-%b %T %Z %z")"] "Saved configuration has been created with error" >> "${mainLog}"
    }
    else {
        echo ["$(date +"%d-%b %T %Z %z")"] "Saved configuration has been created successfully" >> "${mainLog}"
    }
    fi

    # Upload Eb environment configuration
    cd ${scriptsDir}/eb/${env} && eb config put ${appName}-${env}-config

    # Apply Eb environment configuration
    cd ${scriptsDir}/eb/${env} && eb config ${appName}-${env} --cfg ${appName}-${env}-config --timeout "${ebTimeout}"

    # Check Eb environment status
    cd ${scriptsDir}/eb/${env} && eb status | grep Status > "${tmpLog}"
    grep -q "Ready" "${tmpLog}"
    if [ $? -ne 0 ]; then {
        errorsCounter="$[$errorsCounter +1]"
        echo ["$(date +"%d-%b %T %Z %z")"] "Eb Env has been set with error" >> "${mainLog}"
    }
    else {
        echo ["$(date +"%d-%b %T %Z %z")"] "Eb Env has been set successfully" >> "${mainLog}"
    }
    fi

    # Function end time
    functionEndTime=$(date +"%s")

    # Function execution time
    runtime=$((functionEndTime-functionStartTime))

    # Check functions results
    if [ "${errorsCounter}" -gt 0 ]; then {
        echo ["$(date +"%d-%b %T %Z %z")"] "createEbEnv function has been finished with status: ERROR in "${runtime}" sec" >> "${mainLog}"
        endMain
    }
    else {
        echo ["$(date +"%d-%b %T %Z %z")"] "createEbEnv function has been finished with status: SUCCESS in "${runtime}" sec" >> "${mainLog}"
    }
    fi
}

function deployEbApp {
    # Function start time
    functionStartTime=$(date +"%s")

    # Add record to mainLog
    echo "-------" >> "${mainLog}"
    echo ["$(date +"%d-%b %T %Z %z")"] "Working on ""${action}"" action with ""${env}" "environment" >> "${mainLog}"
    echo ["$(date +"%d-%b %T %Z %z")"] "deployEbApp function has been started" >> "${mainLog}"

    # Set tag from git hash
    git -C "${sources}" log --pretty=format:"%h" > "${tmpLog}"
    tag=$(head -1 "${tmpLog}" | tail -1)
    echo ["$(date +"%d-%b %T %Z %z")"] "Git commit hash of deployed version - "${tag}"" >> "${mainLog}"

    # Set message from git commit message
    git -C "${sources}" log --pretty=format:"%s" > "${tmpLog}"
    message=$(head -1 "${tmpLog}" | tail -1)
    echo ["$(date +"%d-%b %T %Z %z")"] "Git commit message of deployed version - "${message}"" >> "${mainLog}"

    cd ${scriptsDir}/eb/"${env}" && eb deploy "${ebCname}" --label "${tag}" --message "${env}"" - ""${message}" --timeout "${ebTimeout}"

    # Check Eb environment status
    cd ${scriptsDir}/eb/"${env}" && eb status | grep Status > "${tmpLog}"
    grep -q "Ready" "$tmpLog"
    if [ $? -ne 0 ]; then {
        errorsCounter="$[$errorsCounter +1]"
        echo ["$(date +"%d-%b %T %Z %z")"] "Eb Env has been updated with error" >> "${mainLog}"
    }
    else {
        echo ["$(date +"%d-%b %T %Z %z")"] "Eb Env has been updated successfully" >> "${mainLog}"

    }
    fi

    # Function end time
    functionEndTime=$(date +"%s")

    # Function execution time
    runtime=$((functionEndTime-functionStartTime))

    # Check functions results
    if [ "${errorsCounter}" -gt 0 ]; then {
        echo ["$(date +"%d-%b %T %Z %z")"] "deployEbApp function has been finished with status: ERROR in "${runtime}" sec" >> "${mainLog}"
        echo "-------" >> "${mainLog}"
        endMain
    }
    else {
        echo ["$(date +"%d-%b %T %Z %z")"] "deployEbApp function has been finished with status: SUCCESS in "${runtime}" sec" >> "${mainLog}"
    }
    fi
}

function addGitHook {
    # Function start time
    functionStartTime=$(date +"%s")

    # Add record to mainLog
    echo "-------" >> "${mainLog}"
    echo ["$(date +"%d-%b %T %Z %z")"] "Working on ""${action}"" action with ""${env}" "environment" >> "${mainLog}"
    echo ["$(date +"%d-%b %T %Z %z")"] "addGitHook function" >> "${mainLog}"

    # Delete old git hook if it's present
    if [ -f "${sources}""/.git/hooks/post-merge" ]; then {
        rm -f "${sources}""/.git/hooks/post-merge"
        echo "Old Git Hook has been removed" >> "${mainLog}"
    }
    fi

    # Create git hook
    cat >> "${sources}""/.git/hooks/post-merge" << EOF
    #!/bin/bash

    # Run deployApp script
    ${scriptsDir}/${scriptName} deploy ${env}
EOF

    # Make git hook executable
    chmod +x "${sources}""/.git/hooks/post-merge"

    # Function end time
    functionEndTime=$(date +"%s")

    # Function execution time
    runtime=$((functionEndTime-functionStartTime))

    # Check git hook
    if [ ! -x "${sources}""/.git/hooks/post-merge" ]; then {
            errorsCounter="$[$errorsCounter +1]"
            echo ["$(date +"%d-%b %T %Z %z")"] "Git hook has been added with error" >> "${mainLog}"
    }
    else {
        echo ["$(date +"%d-%b %T %Z %z")"] "Git hook has been added successfully" >> "${mainLog}"
    }
    fi

    # Check functions results
    if [ "${errorsCounter}" -gt 0 ]; then {
        echo ["$(date +"%d-%b %T %Z %z")"] "addGitHook function has been finished with status: ERROR in "${runtime}" sec" >> "${mainLog}"
        endMain
    }
    else {
        echo ["$(date +"%d-%b %T %Z %z")"] "addGitHook function has been finished with status: SUCCESS in "${runtime}" sec" >> "${mainLog}"
    }
    fi
}

# Execute functions depending on actions
if [ "${action}" == "create" ]; then {
    # Function start time
    functionStartTimeMain=$(date +"%s")

    clearLogs
    installSoftware
    setLogins
    cloneGit
    setGitSchedule
    buildApp
    runLocalApp
    checkLocalApp
    stopLocalApp
    createDockerfile
    deleteDockerContainers
    deleteDockerImages
    buildDockerImage
    runLocalDocker
    checkLocalApp
    deleteDockerContainers
    pushDockerImage
    deleteDockerImages
    createDockerrun
    checkEbCnames
    initEbEnv
    createEbEnv
    checkEbApp
    addGitHook

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
elif [ "${action}" == "deploy" ]; then {
    # Function start time
    functionStartTimeMain=$(date +"%s")

    clearLogs
    installSoftware
    setLogins
    checkGitStatus
    setGitSchedule
    buildApp
    runLocalApp
    checkLocalApp
    stopLocalApp
    createDockerfile
    deleteDockerContainers
    deleteDockerImages
    buildDockerImage
    runLocalDocker
    checkLocalApp
    deleteDockerContainers
    pushDockerImage
    deleteDockerImages
    initEbEnv
    deployEbApp
    checkEbApp

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
elif [ "${action}" == "restore" ]; then {
    # Function start time
    functionStartTimeMain=$(date +"%s")

    clearLogs
    installSoftware
    setLogins
    setGitSchedule
    rewindGit
    buildApp
    runLocalApp
    checkLocalApp
    stopLocalApp
    createDockerfile
    deleteDockerContainers
    deleteDockerImages
    buildDockerImage
    runLocalDocker
    checkLocalApp
    deleteDockerContainers
    pushDockerImage
    deleteDockerImages
    initEbEnv
    deployEbApp
    checkEbApp

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
else {
    echo "Unknown action. Script stopped."
    exit
}
fi
