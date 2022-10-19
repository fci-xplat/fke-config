#!/bin/bash

main_menu() {
    clear
    warning_kubeconfig
    option=0
    until [ "$option" = "5" ]; do
#------ Create Select Menu
    echo -e "\nFKE - Main menu: "
    echo "  1) Nhap 1 de cai dat dashboard K8s"
    echo "  2) Nhap 2 de khoi tao token/kubeconfig"
    echo "  3) Nhap 3 de cai dat ingress"
    echo "  4) Nhap 4 to Exit"
    echo -n "Nhap lua chon cua ban: "
    read option
    echo ""
    case $option in
    1 ) fke_dashboard ;;
    2 ) fke_kubeconfig ;;
    3 ) ingress_menu ;;
    4 ) exit;;
    * ) echo "Nhap sai. Vui long nhap lai!" && exec bash "$0";;
    esac
    done
}

ingress_menu() {
    option_ingress=0
    until [ "$option_ingress" = "5" ]; do
    echo -e "\nFKE - Ingress menu: "
    echo "  1) Nhap 1 de cai dat nginx ingress"
    # echo "  2) Nhap 2 de cai dat kong ingress"
    # echo "  3) Nhap 3 de cai dat haproxy ingress"
    # echo "  4) Nhap 3 de cai dat traefik ingress"
    # echo "  5) Nhap 3 de cai dat istio ingress"
    echo "  6) Nhap 6 to Exit"
    echo -n "Nhap lua chon cua ban: "
    read option_ingress
    echo ""
    case $option_ingress in
    1 ) target_ingress="nginx" && fke_ingress ;;
    2 ) target_ingress="kong" && fke_ingress ;;
    3 ) target_ingress="haproxy" && fke_ingress ;;
    4 ) target_ingress="traefik" && fke_ingress ;;
    5 ) target_ingress="istio" && fke_ingress ;;
    6 ) exit;;
    * ) echo "Nhap sai. Vui long nhap lai!" && exec bash "$0";;
    esac
    done
}

warning_kubeconfig()
{
    echo -e "\nCopyright FPT Smart Cloud\n"
    echo -e "Chu y! De truy cap den cum K8s:"
    echo -e "  - May tinh cua ban can cai dat kubectl. Thong tin chi tiet: https://kubernetes.io/vi/docs/tasks/tools/install-kubectl/"
    echo -e "  - Tai ve file Kubeconfig cum K8s cua ban tren giao dien quan tri console.fptcloud.com, muc Kubenetes "
    echo -e "  - Sao chep file Kubeconfig vao may tinh va chay lenh: export KUBECONFIG=/duong/dan/file/kubeconfig\n"
}

check_cluster()
{
    kubectl cluster-info >/dev/null
    if [ $? -eq 0 ]; then
        echo ""
    else
        echo -e "  - Ban chua ket noi duoc toi cum K8s: Kiem tra ket noi mang hoac cau hinh: export KUBECONFIG=/duong/dan/file/kubeconfig\n"
    fi
}


fke_kubectl()
{
    kubectl version --client >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo ""
    else
        echo -e "\nkubectl chua duoc cai dat. Ban co muon cai dat kubectl khong? (yes/no)\n"
        read option_kubectl
        if [ "$option_kubectl" == "yes" ] || [ "$option_kubectl" == "y" ]; then
            echo -e "Nhap phien ban kubectl can cai dat (default: $(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt) )\nThong tin cac phien ban tham khao: https://kubernetes.io/vi/docs/tasks/tools/install-kubectl/"
            read kubectl_version
                if [ -z "$kubectl_version" ]; then
                    curl -LO https://storage.googleapis.com/kubernetes-release/release/`curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt`/bin/linux/amd64/kubectl >/dev/null
                    chmod +x ./kubectl
                    sudo mv ./kubectl /usr/local/bin/kubectl
                    kubectl version --client >/dev/null 2>&1
                    if [ $? -eq 0 ]; then
                        echo -e "\nCai dat kubectl phien ban $(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt) thanh cong.\n"
                    else
                        echo -e "\nCai dat kubectl phien ban $(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt) that bai.\n"
                    fi
                else
                    curl -LO https://storage.googleapis.com/kubernetes-release/release/$kubectl_version/bin/linux/amd64/kubectl >/dev/null
                    chmod +x ./kubectl
                    sudo mv ./kubectl /usr/local/bin/kubectl
                    kubectl version --client >/dev/null 2>&1
                    if [ $? -eq 0 ]; then
                        echo -e "\nCai dat kubectl phien ban $kubectl_version thanh cong.\n"
                    else
                        echo -e "\nCai dat kubectl phien ban $kubectl_version that bai.\n"
                    fi
                fi

        else
            echo ""
        fi
    fi

}

fke_dashboard()
{
    fke_kubectl
    check_cluster
    echo -e "Nhap phien ban Dashboard can cai dat (default: v2.6.1)\nThong tin cac phien ban tham khao: https://github.com/kubernetes/dashboard"
    read dashboard_version
    if [ -z "$dashboard_version" ]; then
        kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.6.1/aio/deploy/recommended.yaml
        if [ $? -eq 0 ]; then
            echo -e "\nCai dat K8s dashboard phien ban v2.6.1 thanh cong.\n"
        else
            echo -e "\nCai dat K8s dashboard phien ban v2.6.1 that bai.\n"
        fi
    else
        kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/$dashboard_version/aio/deploy/recommended.yaml
        if [ $? -eq 0 ]; then
            echo -e "\nCai dat K8s dashboard phien ban $dashboard_version thanh cong.\n"
            echo -e "\nDe truy cap vao dashboard: \n  - Chay lenh: kubectl proxy \n  - Truy cap vao duong dan: http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/#!/login"
            echo "  - De login vao dashboard, ban can khoi tao token/kubeconfig"
        else
            echo -e "\nCai dat K8s dashboard phien ban $dashboard_version that bai.\n"
        fi
    fi
}

fke_kubeconfig()
{
    fke_kubectl
    check_cluster
    echo "  - Khoi tao service account: fke-admin"
    kubectl apply -f https://raw.githubusercontent.com/fci-xplat/fke-config/main/fke_sa_rbac.yml
    TOKENNAME=`kubectl -n kube-system get serviceaccount/fke-admin -o jsonpath='{.secrets[0].name}'`
    TOKEN=`kubectl -n kube-system get secret $TOKENNAME -o jsonpath='{.data.token}'| base64 --decode`
    echo "  - Set credentials, context"
    kubectl config set-credentials fke-admin --token=$TOKEN
    kubectl config set-context --current --user=fke-admin
    echo -e "\n  - Token de truy cap vao Dashboard"
    echo $TOKEN
    echo -e "\n  - File Kubeconfig moi de truy cap vao Dashboard"
    echo $KUBECONFIG
}

fke_helm()
{
    echo "  - Ban co muon cai dat helm khong? (yes/no)"
    read option_helm
    if [ "$option_helm" == "yes" ] || [ "$option_helm" == "y" ]; then
        curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
        chmod 700 get_helm.sh && ./get_helm.sh
        if [ $? -eq 0 ]; then
            echo -e "\n  - Cai dat helm thanh cong.\n"
        else
            echo -e "\n  - Cai dat helm that bai.\n"
        fi
    else
        echo ""
    fi
}

fke_ingress()
{
    check_cluster
    fke_helm
    if [ $target_ingress = "nginx" ]; then
        helm repo add nginx-stable https://helm.nginx.com/stable && helm repo update
        helm install nginx-ingress nginx-stable/nginx-ingress --set rbac.create=true
        kubectl get pods --all-namespaces -l app=nginx-ingress-nginx-ingress
        if [ $? -eq 0 ]; then
            echo -e "\n  - Cai dat nginx ingress thanh cong.\n"
        else
            echo -e "\n  - Cai dat nginx ingress that bai.\n"
        fi
    elif [ $target_ingress = "haproxy" ]; then
        echo "haproxy"
    else
        exit
    fi

}

main() {
    main_menu
}
main
