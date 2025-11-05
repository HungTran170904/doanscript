#!/bin/bash
# ===============================
# Script: check_namespace.sh
# Mục đích: Kiểm tra namespaces và tạo mới nếu cần
# ===============================

echo "==============================="
echo " Danh sách Namespace hiện có:"
echo "==============================="
kubectl get namespaces

echo
read -p "Bạn có muốn tạo thêm namespace mới không? (y/n): " create_ns

if [[ "$create_ns" == "y" || "$create_ns" == "Y" ]]; then
    read -p "Nhập tên namespace bạn muốn tạo: " ns_name

    # Kiểm tra namespace đã tồn tại chưa
    if kubectl get namespace "$ns_name" > /dev/null 2>&1; then
        echo "Namespace '$ns_name' đã tồn tại. Không cần tạo lại."
    else
        echo "Đang tạo namespace '$ns_name'..."
        kubectl create namespace "$ns_name"
        if [ $? -eq 0 ]; then
            echo "✅ Tạo namespace '$ns_name' thành công!"
        else
            echo "❌ Lỗi khi tạo namespace '$ns_name'!"
        fi
    fi
else
    echo " Không tạo namespace mới. Kết thúc script."
fi
