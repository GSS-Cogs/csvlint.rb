pipeline {
    agent {
        label 'master'
    }
    stages {
        stage('Test') {
            agent {
                docker {
                    image 'ruby:2.4.3-alpine'
                }
            }
            steps {
                sh "bundle test"
            }
        }
    }
}
