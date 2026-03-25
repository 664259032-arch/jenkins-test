pipeline {
    agent any

    options {
        skipDefaultCheckout(true)
    }

    environment {     
        DOCKER_HUB_CREDENTIALS_ID = 'docker-jenkins-test'
        DOCKER_REPO               = "aomezzz007/flask-docker-app"

        DEV_APP_NAME              = "flask-app-dev"
        DEV_HOST_PORT             = "5001"
        PROD_APP_NAME             = "flask-app-prod"
        PROD_HOST_PORT            = "5000"
    }

    parameters {
        choice(name: 'ACTION', choices: ['Build & Deploy', 'Rollback'], description: 'เลือก Action ที่ต้องการ')
        string(name: 'ROLLBACK_TAG', defaultValue: '', description: 'สำหรับ Rollback: ใส่ Image Tag (เช่น Git Hash หรือ dev-123)')
        choice(name: 'ROLLBACK_TARGET', choices: ['dev', 'prod'], description: 'สำหรับ Rollback: เลือก Environment')
    }

    stages {
        stage('Checkout') {
            when { expression { params.ACTION == 'Build & Deploy' } }
            steps {
                echo "Checking out code..."
                checkout scm
            }
        }

        stage('Install & Test') {
            when { expression { params.ACTION == 'Build & Deploy' } }
            steps {
                echo "Running tests inside Python Docker container..."
                script {
                    docker.image('python:3.13-slim').inside {
                        sh '''
                            pip install --no-cache-dir -r requirements.txt
                            pytest -v --tb=short --junitxml=test-results.xml || true
                        '''
                    }
                }
            }
            post {
                always {
                    junit 'test-results.xml'
                }
            }
        }

        stage('Build & Push Docker Image') {
            when { expression { params.ACTION == 'Build & Deploy' } }
            steps {
                script {
                    def branchName = env.BRANCH_NAME ?: 'dev'
                    env.IMAGE_TAG = (branchName == 'main') ? sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim() : "dev-${env.BUILD_NUMBER}"

                    docker.withRegistry('https://index.docker.io/v1/', DOCKER_HUB_CREDENTIALS_ID) {
                        echo "Building image: ${DOCKER_REPO}:${env.IMAGE_TAG}"
                        def customImage = docker.build("${DOCKER_REPO}:${env.IMAGE_TAG}")
                        echo "Pushing image..."
                        customImage.push()
                        if (branchName == 'main') {
                            customImage.push('latest')
                        }
                    }
                }
            }
        }

        stage('Approval for Production') {
            when { expression { params.ACTION == 'Build & Deploy' } }
            steps {
                timeout(time: 1, unit: 'HOURS') {
                    input message: "Deploy image tag '${env.IMAGE_TAG}' to PRODUCTION (Local Docker on port ${PROD_HOST_PORT})?"
                }
            }
        }

        stage('Deploy to PRODUCTION (Local Docker)') {
            when {
                expression { params.ACTION == 'Build & Deploy' }
                branch 'main'
            }
            steps {
                script {
                    echo "Deploying container ${PROD_APP_NAME}..."
                    sh """
                        docker pull ${DOCKER_REPO}:${env.IMAGE_TAG}
                        docker stop ${PROD_APP_NAME} || true
                        docker rm ${PROD_APP_NAME} || true
                        docker run -d --name ${PROD_APP_NAME} -p ${PROD_HOST_PORT}:5000 ${DOCKER_REPO}:${env.IMAGE_TAG}
                        docker ps --filter name=${PROD_APP_NAME} --format "table {{.Names}}\\t{{.Image}}\\t{{.Status}}"
                    """
                    echo "[INFO] Deploy completed for PRODUCTION."
                }
            }
        }

        stage('Execute Rollback') {
            when { expression { params.ACTION == 'Rollback' } }
            steps {
                script {
                    if (params.ROLLBACK_TAG.trim().isEmpty()) {
                        error "เมื่อเลือก Rollback กรุณาระบุ 'ROLLBACK_TAG'"
                    }

                    env.TARGET_APP_NAME  = (params.ROLLBACK_TARGET == 'dev') ? env.DEV_APP_NAME  : env.PROD_APP_NAME
                    env.TARGET_HOST_PORT = (params.ROLLBACK_TARGET == 'dev') ? env.DEV_HOST_PORT : env.PROD_HOST_PORT
                    def imageToDeploy = "${DOCKER_REPO}:${params.ROLLBACK_TAG.trim()}"

                    echo "ROLLING BACK ${params.ROLLBACK_TARGET.toUpperCase()} to image: ${imageToDeploy}"
                    sh """
                        docker pull ${imageToDeploy}
                        docker stop ${env.TARGET_APP_NAME} || true
                        docker rm ${env.TARGET_APP_NAME} || true
                        docker run -d --name ${env.TARGET_APP_NAME} -p ${env.TARGET_HOST_PORT}:5000 ${imageToDeploy}
                    """
                    echo "[INFO] Rollback completed."
                }
            }
        }
    }

    post {
        always {
            script {
                if (params.ACTION == 'Build & Deploy') {
                    echo "Cleaning up Docker images..."
                    try {
                        sh """
                            docker image rm -f ${DOCKER_REPO}:${env.IMAGE_TAG} || true
                            docker image rm -f ${DOCKER_REPO}:latest || true
                        """
                    } catch (err) {
                        echo "Could not clean up images, but continuing..."
                    }
                }
                echo "Cleaning workspace..."
                cleanWs()
            }
        }
        failure {
            echo "[ERROR] Pipeline Failed"
        }
    }
}