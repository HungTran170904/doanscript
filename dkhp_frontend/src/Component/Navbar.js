import React, { useContext, useEffect, useState } from "react";
import { Link } from "react-router-dom"
import { getStudentInfo } from "../API/StudentAPI";
import { ClientContext } from "../Router/ClientRouter";
const NavBar = () => {
    const {setError}=useContext(ClientContext);
    const [studentData, setStudentData]=useState(null);
    useEffect(()=>{
        getStudentInfo().then(res=>{
                setStudentData(res.data)
        })
        .catch((err)=>setError(err))
    },[])
    return (
        <nav className="navbar navbar-expand-lg navbar-light bg-light h6">
            <Link className="navbar-brand" to="/">Course Registration App</Link>
            <div className="collapse navbar-collapse" id="navbarText">
                <ul className="navbar-nav mr-auto">
                    <li className="nav-item active">
                        <Link className="nav-link" to="/OpenedCourses">DKHP</Link>
                    </li>
                    <li className="nav-item">
                        <Link className="nav-link" to="/RegisteredCourses">Môn Đã ĐK</Link>
                    </li>
                    <li className="nav-item">
                        <Link className="nav-link" to="/TimeTable">Thời khóa biểu</Link>
                    </li>
                    {studentData!=null&&(
                        <li className="nav-item dropdown">
                            <Link className="nav-link dropdown-toggle" to="/StudentInfo" data-bs-toggle="dropdown" aria-expanded="false"><i className="bi bi-person-circle"/> Sinh Viên</Link>
                                <ul className="dropdown-menu">
                                <li className="dropdown-item">{studentData.user.userId}</li>
                                <li className="dropdown-item">{studentData.user.name}</li>
                                <li className="dropdown-item">{studentData.falcutyName} - {studentData.khoaTuyen}</li>
                                <li className="dropdown-item">Ngành {studentData.program}</li>
                                <li><hr className="dropdown-divider"/></li>
                                <li><Link to="/login" onClick={()=>{localStorage.removeItem("Authorization")}}><i className="bi bi-box-arrow-right"/>  Logout</Link></li>
                                </ul>
                        </li>
                    )}
                </ul>
            </div>
        </nav>
    );
}

export default NavBar;