#!/usr/bin/groovy
import groovy.json.JsonOutput
import java.util.Optional
import hudson.model.Result

def appName = 'neb-ecommerce'
def timestamp = System.nanoTime()
def podLabel = 'jenkins-' + appName + '-' + timestamp
def teamsWebhookUrl = 'https://abc.webhook.office.com/webhookb2/0da82d74-7e30-4131-9633-/JenkinsCI/akajkhjajckakc
podTemplate(label: podLabel, containers: [
    containerTemplate(name: 'jnlp', image: 'jenkins/jnlp-slave:4.7-1-alpine', alwaysPullImage: false, args: '${computer.jnlpmac} ${computer.name}', workingDir: "/var/jenkins_home", resourceRequestCpu: '200m', resourceLimitCpu: '300m', resourceRequestMemory: '256Mi', resourceLimitMemory: '512Mi'),
    containerTemplate(name: 'img', image: 'harbor.app.abc.com/com/tools:v0.1.0', ttyEnabled: true,  alwaysPullImage: true, privileged : true,  command: 'cat')
    ],

    volumes:[
         hostPathVolume(mountPath: '/var/run/docker.sock', hostPath: '/var/run/docker.sock'),
         hostPathVolume(mountPath: '/usr/bin/docker', hostPath: '/usr/bin/docker'),
        ],
    imagePullSecrets:["harbor-jenkins-secret"],
        ) {

  node (podLabel) {
    //   properties([disableConcurrentBuilds()])
    try {

        def msg = buildNotificationMsg('STARTED')
        office365ConnectorSend webhookUrl: "${teamsWebhookUrl}", message: "${msg}", status: "Started"

        def pwd = pwd()
        
        stage ('Clean') {
            deleteDir()
          }
        
        def exitCode = 0

        stage('Checkout') {
            ansiColor('xterm') {
                println "Checkout the git repo"
                checkout scm
            }
        }

        def commitId = sh(script: 'git rev-parse --verify --short HEAD', returnStdout: true).trim()
        def branch = sh(script: 'git rev-parse --abbrev-ref HEAD', returnStdout: true).trim() 
        def tag = sh(script: 'git tag --contains', returnStdout: true).trim() 
        def userInput = false
        
        // read in required jenkins workflow config values
        println "Loading Pipeline config"
        def inputFile = readFile('jenkinsfile.json')
        def config = new groovy.json.JsonSlurperClassic().parseText(inputFile)
        println "pipeline config ==> ${config}"
        def projectName = config.project_name
        def dockerUrl = config.docker_registry

        // if (env.BRANCH_NAME =~ 'PR-*') {

            // container('gatsbyjs') {  
            //     stage ('Build Image') {
            //         ansiColor('xterm') {
            //             exitCode = sh(script: """
            //                 gatsby build
            //             """, returnStatus: true)
            //         }
            //     } 
            // }


        if (env.BRANCH_NAME =~ 'develop') {
            container('img') {  
                stage ('Build & Push Image for QA') {
                    
                    withCredentials([usernamePassword(
                        credentialsId: "harbor-jenkins-user",
                        usernameVariable: "USERNAME",
                        passwordVariable: "PASSWORD"
                    )
                    ]) {
                        ansiColor('xterm') {
                            exitCode = sh(script: """
                                img login ${dockerUrl} -u ${USERNAME} -p ${PASSWORD}
                                img build -t  harbor.app.abc.com/com/app:${commitId} -f Dockerfile.qa ./
                                img push harbor.app.abc.com/com/app:${commitId} 
                            """, returnStatus: true)
                        }
                    }
                    
                }  
            }

            stage("Deploy") {
                println("deploying qa in k8s")

                exitCode = sh(script: """
                    sed -i.bak "s#__IMG_TAG__#${commitId}#" ./chart-qa/deployment.yaml 
                """, returnStatus: true)

                kubernetesDeploy(
                 kubeconfigId: 'xyz-aks',             
                 configs: 'chart-qa/deployment.yaml', 
                 enableConfigSubstitution: false,
                        secretNamespace: 'default',
                        secretName: 'harbor-jenkins-secret',
                        dockerCredentials: [
                            [credentialsId: 'harbor-jenkins-user', url: "https://${dockerUrl}"],
                        ],
                )
            }
        }

        if (env.BRANCH_NAME =~ 'release-*') {

            stage ('Build & Push Image for PROD') {
                container('img') {  

                    ansiColor('xterm') {
                        exitCode = sh(script: """
                            chmod +x ./scripts/build.sh
                            ./scripts/build.sh 
                        """, returnStatus: true)
                    }

                    if (exitCode != 0) {
                        throw new Exception("""Deployment script exits with ${exitCode}""")
                    } else currentBuild.result = "SUCCESS"
                    
                    withCredentials([usernamePassword(
                        credentialsId: "harbor-jenkins-user",
                        usernameVariable: "USERNAME",
                        passwordVariable: "PASSWORD"
                    )
                    ]) {
                        ansiColor('xterm') {
                            exitCode = sh(script: """
                                img login ${dockerUrl} -u ${USERNAME} -p ${PASSWORD}
                                img build -t  harbor.app.abc.com/com/app:${commitId} ./
                                img push harbor.app.abc.com/com/app:${commitId} 
                            """, returnStatus: true)
                        }
                    }
                    
                }  
            }

            stage("Deploy") {
                
                println("deploying qa in k8s")

                exitCode = sh(script: """
                    sed -i.bak "s#__IMG_TAG__#${commitId}#" ./chart-prod/deployment.yaml 
                """, returnStatus: true)

                kubernetesDeploy(
                 kubeconfigId: 'xyz-aks',             
                 configs: 'chart-prod/deployment.yaml', 
                 enableConfigSubstitution: false,
                        secretNamespace: 'default',
                        secretName: 'harbor-jenkins-secret',
                        dockerCredentials: [
                            [credentialsId: 'harbor-jenkins-user', url: "https://${dockerUrl}"],
                        ],
                )
            }
        }

        if (env.BRANCH_NAME =~ 'master') {}

        if (exitCode != 0) {
            throw new Exception("""Deployment script exits with ${exitCode}""")
        } else currentBuild.result = "SUCCESS"
        
        //  when { tag "release-*" } # For pro
    } catch(error) {
        currentBuild.result = "FAILURE"
    } finally {
        def msg = buildNotificationMsg(currentBuild.result)
        office365ConnectorSend webhookUrl: "${teamsWebhookUrl}", message: "${msg}", status: "${currentBuild.result}"

    }
  }
}


def buildNotificationMsg(def buildStatus) {

    def colorMap = [ 'STARTED': '#FF8000', 'SUCCESS': '#04B404', 'WAITING_FOR_APPROVAL': '#0040FF', 'FAILURE': '#FF0000' ]
    try {
        def subject = "Pipeline: ${env.JOB_NAME} - #${env.BUILD_NUMBER} - Branch: ${env.BRANCH_NAME} :: ${buildStatus} "
        def summary = ""
        if (buildStatus == 'STARTED') summary = subject else {
            summary = """
                ${subject} \n
                Build Number: ${env.BUILD_NUMBER} \n
                Build URL: ${env.BUILD_URL} \n
                Short Commit Hash:  ${getShortCommitHash()} \n
                Branch Name: ${env.BRANCH_NAME} - ${getCurrentBranch()} \n
                Author:  ${getChangeAuthorName()} (${getChangeAuthorEmail()}) \n
                Change Set:  ${getChangeSet()} \n
                ChangeLog:  ${getChangeLog()} \n
            """
        }  
        if (buildStatus == 'WAITING_FOR_APPROVAL') {
            summary = """
                Waiting for approval for deployment started by ${getChangeAuthorName()} (${getChangeAuthorEmail()}) \n
                Build Number: ${env.BUILD_NUMBER} \n
                Build URL: ${env.BUILD_URL} \n
                Short Commit Hash:  ${getShortCommitHash()} \n
            """
        }
        def colorName = colorMap[buildStatus]

        // slackSend (color: colorName, message: summary, channel: "#dev")
        return summary
    } catch(e) {
        println e
    }
}

def getShortCommitHash() {
    return sh(returnStdout: true, script: "git log -n 1 --pretty=format:'%h'").trim()
}

def getChangeAuthorName() {
    return sh(returnStdout: true, script: "git show -s --pretty=%an").trim()
}

def getChangeAuthorEmail() {
    return sh(returnStdout: true, script: "git show -s --pretty=%ae").trim()
}

def getChangeSet() {
    return sh(returnStdout: true, script: 'git diff-tree --no-commit-id --name-status -r HEAD').trim()
}

def getChangeLog() {
    return sh(returnStdout: true, script: "git log --date=short --pretty=format:'%ad %aN <%ae> %n%n%x09* %s%d%n%b'").trim()
}

def getCurrentBranch () {
    return sh (
            script: 'git rev-parse --abbrev-ref HEAD',
            returnStdout: true
    ).trim()
}
