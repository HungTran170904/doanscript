import React, { useState, useEffect, useRef, useContext, useMemo } from "react";
import CourseTable from "../Component/CourseTable";
import { enrollCourses } from "../API/StudentAPI";
import { ClientContext} from "../Router/ClientRouter";
import { OpenedCourses_ResultModal } from "../Component/Modal";
const OpenedCoursesPage=()=>{
          const {courseData,setError}=useContext(ClientContext);
          const[modal, setModal]=useState({show:false, data:[]});
          const [checkedIds, setCheckedIds]=useState(new Set());
          const [isDKButtonDisabled, setIsDKButtonDisabled]=useState(true);
          const [searchTerm, setSearchTerm]=useState("");
          const [search, setSearch]=useState("");
          function handleDKButton(e){
                e.preventDefault();
                enrollCourses([...checkedIds]).then(res=>{
                        setModal({show:true, data:new Map(Object.entries(res.data))});
                        setCheckedIds(new Set())
                })
                .catch(err=>setError(err))
            }
            const handleClose=()=>{
                  setModal({show:false, data:[]});
            }
          useEffect(()=>{
                if(checkedIds.size===0) setIsDKButtonDisabled(true);
                else setIsDKButtonDisabled(false);
          },[checkedIds])
          const handleFilter = (item) => {
                const re = new RegExp("^"+search,"i");
                return item.courseId.match(re);
        }
          let filterCourses=(search==="")?courseData:courseData.filter(handleFilter);
         return(
          <>
          <div className="main-page">
                    <div className="ContentAlignment">
                              <h4>Danh sách lớp mở chờ đăng kí</h4>
                              <button type="button" className="btn btn-primary" onClick={(e)=>handleDKButton(e)} disabled={isDKButtonDisabled}>Đăng kí</button>
                              <form className="d-flex col-lg-6" role="search" onSubmit={(e)=>{e.preventDefault(); setSearch(searchTerm);}}>
                                        <input className="form-control me-2" type="search" placeholder="Tìm kiếm theo mã lớp" id="Search" onChange={(e)=>setSearchTerm(e.target.value)}/>
                                        <button className="btn btn-outline-success" type="submit" >Search</button>
                              </form>
                    </div>
                    <CourseTable filterCourses={filterCourses} checkedIds={checkedIds} setCheckedIds={setCheckedIds}/>
          </div>
           <OpenedCourses_ResultModal modal={modal} handleClose={handleClose}/>
          </>
         );
}
export default OpenedCoursesPage;