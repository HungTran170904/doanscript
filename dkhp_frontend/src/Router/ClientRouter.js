import { Route, Routes, useLocation, useNavigate } from "react-router-dom";
import OpenedCoursesPage from "../Page/OpenedCoursesPage";
import ErrorPage from "../Page/ErrorPage";
import NavBar from "../Component/Navbar";
import RegisteredCoursesPage from "../Page/RegisteredCoursesPage";
import DashboardPage from "../Page/DashboardPage";
import { createContext, useEffect, useState } from "react";
import { getOpenedCourses, getUpdatedRegNumbers } from "../API/CourseAPI";
import TimeTablePage from "../Page/TimeTablePage";
import { useSnackbar } from "notistack";

export const ClientContext= createContext();
function ClientRouter(){
     const { enqueueSnackbar } = useSnackbar();
     const navigate = useNavigate();
     const [courseData, setCourseData]=useState([]);
     const [regNumbers, setRegNumbers]=useState(new Map());
     const[error, setError]=useState(null);
     let anchorOrigin = { horizontal: 'center' , vertical: 'bottom'}
     useEffect(()=>{
          const updatedRegNumbers=new Map();
          for(let c of courseData) updatedRegNumbers.set(c.id+"", c.registeredNumber);
          setRegNumbers(updatedRegNumbers);
     }, [courseData])
     async function loadCourseData(){
          getOpenedCourses().then(res=>{
               setCourseData(res.data);
               setError(null);
          })
          .catch(err=>setError(err))
     }
     function logOut(){
          localStorage.removeItem("Authorization");
          localStorage.removeItem("Role");
          navigate("/login");
     }
     useEffect(()=>{
          let sseClient=getUpdatedRegNumbers(setRegNumbers);
          return ()=>sseClient.close();
     },[])
     useEffect(()=>{
          if(error!=null){
               if(error.response.status==401) logOut();
               let config = {variant: 'error',anchorOrigin:anchorOrigin}
               enqueueSnackbar(error.response.data,config);
          }
     },[error])
     useEffect(()=>{
          if(courseData.length==0) loadCourseData();
     },[])
return(
<ClientContext.Provider value={{courseData,regNumbers, setError}}>
          <NavBar/>
          <Routes>
                    <Route exact path="/" element={<DashboardPage />}/>
                    <Route path="/OpenedCourses" element={<OpenedCoursesPage/>}/>
                    <Route path="/RegisteredCourses" element={<RegisteredCoursesPage/>}/>
                    <Route path="/TimeTable" element={<TimeTablePage/>}/>
                    <Route path="/*" element={<ErrorPage message="404 Error! Page Not Found"/>}/>
          </Routes>
     </ClientContext.Provider>
)
}
export default ClientRouter;