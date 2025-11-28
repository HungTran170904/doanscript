const DashboardPage = () =>(
    <div
        style={{
           display: "flex",
            flexDirection: "column",
            justifyContent: "center",
            alignItems: "center",
            gap: "15px"
        }}
    >
        <h3 style={{ marginBottom: "20px" }}>TRANG ĐĂNG KÝ HỌC PHẦN</h3>
        <div className="border border-dark rounded" style={{padding:"10px"}}>
                <h5>SINH VIÊN THOÁT RA ĐĂNG NHẬP LẠI NẾU BỊ LỖI KHÔNG TẢI ĐƯỢC DANH SÁCH</h5>
                <h5>HƯỚNG DẪN ĐĂNG KÝ HỌC PHẦN</h5>
                <ol>
                        <li>Nhấn vào trình đơn Đăng ký Học phần</li>
                        <li>Chọn các lớp cần đăng ký</li>
                        <li>Nhấn vào nút Đăng ký</li>
                        <li>Chờ hệ thống xử lỳ và hoàn thành xử lý</li>
                        <li>Sau khi có kết quả xử lý, sinh viên kiểm tra và thực hiện chọn đăng ký tiếp, quay lại bước 1</li>
                </ol>
        </div>
    </div>
);
export default DashboardPage;