import { useContext, useEffect, useState } from "react";
import { addCourse, getAllCourses, removeCourse } from "../API/CourseAPI";
import { getLatestSemesters } from "../API/AminAPI";
import CourseForm from "../AdminComponent/CourseForm";
import { Alert, Button, Modal } from "react-bootstrap";
import { AdminContext } from "../Router/AdminRouter";
import TableHeader from "../Component/TableHeader";
import { formatDate } from "../Util/FormatDateTime";
import { FormModal, ResultAlert } from "../AdminComponent/ModalAndAlert";
import { useSnackbar } from "notistack";

const CoursePage=()=>{
          const {setError}=useContext(AdminContext);
          const [courseData, setCourseData]=useState([]);
          const[show, setShow]=useState(0); //0: not show, 1: show FormModal
          const [searchTerm, setSearchTerm]=useState("");
          const [search, setSearch]=useState("");
          const [semesters, setSemesters]=useState([]);
          const { enqueueSnackbar } = useSnackbar();
          const config = {variant: '',anchorOrigin:{ horizontal: 'center' , vertical: 'bottom'}}
          const courseDTO= {
                courseId: "",
                beginDate: null,
                endDate: null,
                language: "VN",
                beginShift: 1,
                endShift: 1,
                dayOfWeek: 2,
                totalNumber: 0,
                weekDistance: 1,
                room: "",
                lecturerName: "",
                mainCourseId: null,
                semesterId: 0
          };
          useEffect(()=>{
            getAllCourses().then(res=>{
                setCourseData(res.data);
            })
            .catch(err=>setError(err))
            getLatestSemesters().then(res=>{
                setSemesters(res.data)
            })
            .catch(err=>setError(err))
          },[])
          const handleAddButton=(e)=>{
                e.preventDefault();
                setShow(1);
            }
            const handleDelButton=(e,id)=>{
                    e.preventDefault();
                    removeCourse(id).then(res=>{
                        setCourseData((prevCourseData)=>{
                            const updatedCourseData=prevCourseData.filter((data)=>{return data.id!=id});
                            return updatedCourseData;
                        })
                        setShow(0);
                        config.variant="success"
                        enqueueSnackbar("Xóa thành công lớp "+res.data, config)
                    })
                    .catch(err=>setError(err))
                }
          const handleFilter = (item) => {
                const re = new RegExp("^"+search,"i");
                return item.courseId.match(re);
        }
        const handleSubmit=()=>{
            addCourse(courseDTO).then(res=>{
                setCourseData((prevCourseData)=>{
                    const updatedCourseData=[...prevCourseData];
                    updatedCourseData.push(res.data);
                    return updatedCourseData;
                })
                setShow(0);
                config.variant="success"
                enqueueSnackbar("Thêm thành công lớp "+res.data.courseId, config)
            })
            .catch(err=>{
                if(err.response.status==400){
                    config.variant="error";
                    enqueueSnackbar(err.response.data, config);
                }
                else setError(err)
            })
        }
          let filterCourses=(search==="")?courseData:courseData.filter(handleFilter);
          return(
          <>
          <div className="main-page">
                    <div className="ContentAlignment">
                              <h1>Danh sách các lớp đã mở</h1>
                              <button  type="button" className="btn btn-success" onClick={(e)=>handleAddButton(e)}>Add Course</button>
                              <form className="d-flex col-lg-6" role="search" onSubmit={(e)=>{e.preventDefault(); setSearch(searchTerm);}}>
                                        <input className="form-control me-2" type="search" placeholder="Tìm kiếm theo mã lớp" id="Search" onChange={(e)=>setSearchTerm(e.target.value)}/>
                                        <button className="btn btn-outline-success" type="submit" >Search</button>
                              </form>
                    </div>
                    <div className="TableWapper border-bottom border-dark">
                        <table className="table table-hover">
                            <TableHeader data={["Mã Lớp","Môn học","SốTC","Thời gian học","ĐãDK/Sĩ số","Action"]} />
                            <tbody>
                        {filterCourses?.map((data)=> {
                                return (
                                    <tr key={data.id}>
                                        <th>{data.courseId}</th>
                                        <td>{data.subject.subjectName}</td>
                                        <td>{data.subject.theoryCreditNumber}</td>
                                        <td>Thứ {data.dayOfWeek}, tiết {data.beginShift}-{data.endShift}, giảng viên: {data.lecturerName==undefined?'Chưa có':data.lecturerName}, 
                                        ngôn ngữ: {data.language}, cách tuần: {data.weekDistance}, từ {formatDate(data.beginDate)} đến {formatDate(data.endDate)}</td>
                                        <td>{data.registeredNumber}/{data.totalNumber}</td>
                                        <td colSpan={2}>
                                                  <button type="button" className="btn btn-danger mr-2" onClick={(e)=>handleDelButton(e,data.id)}>Delete</button>
                                                  <button type="button" className="btn btn-primary">Modify</button>
                                        </td>
                                    </tr>
                                )
                            })}
                            </tbody>
                        </table>
                    </div>
          </div>
            {show==1&&<FormModal setShow={setShow} handleSubmit={handleSubmit} title="THÊM HỌC PHẦN"><CourseForm courseDTO={courseDTO} semesters={semesters}/></FormModal>}
          </>
          )
}
export default CoursePage;