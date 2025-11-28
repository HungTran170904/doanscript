import { Route, Routes, useNavigate } from "react-router-dom";
import ErrorPage from "../Page/ErrorPage"
import { createContext, useEffect, useState } from "react";
import CoursePage from "../AdminPage/CoursePage";
import { useSnackbar } from "notistack";
import SubjectPage from "../AdminPage/SubjectPage";
import AdminNavBar from "../AdminComponent/AdminNavbar";
import StudentPage from "../AdminPage/StudentPage";
import WelcomePage from "../AdminPage/WelcomePage";
import OpeningRegPeriod from "../AdminPage/OpeningRegPeriod";
import SemesterPage from "../AdminPage/SemesterPage";

export const AdminContext= createContext();
function AdminRouter(){
          const { enqueueSnackbar } = useSnackbar();
          const[error, setError]=useState(null);
          const navigate = useNavigate();
          let anchorOrigin = { horizontal: 'center' , vertical: 'bottom'}
          const logOut=()=>{
               localStorage.removeItem("Authorization");
               localStorage.removeItem("Role")
               navigate("/login");
          }
          useEffect(()=>{
               if(error!=null&&error.response){
                    if(error.response.status==401) logOut();
                    let config = {variant: 'danger',anchorOrigin:anchorOrigin}
                    enqueueSnackbar(error.response.data,config);
               }
          },[error])
          return(
                    <AdminContext.Provider value={{setError}}>
                         <AdminNavBar/>
                         <Routes>
                                   <Route exact path="/" element={<WelcomePage/>}/>
                                   <Route path="/CoursePage" element={<CoursePage/>}/>
                                   <Route path="/SubjectPage" element={<SubjectPage/>}/>
                                   <Route path="/StudentPage" element={<StudentPage/>}/>
                                   <Route path="/OpeningRegPeriod" element={<OpeningRegPeriod/>}/>
                                   <Route path="/SemesterPage" element={<SemesterPage/>}/>
                                   <Route path="/*" element={<ErrorPage message="404 Not Found!"/>}/>
                         </Routes>
                    </AdminContext.Provider>
          )
}
export default AdminRouter;