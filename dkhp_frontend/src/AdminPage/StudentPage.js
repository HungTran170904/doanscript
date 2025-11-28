import { useContext, useEffect, useState } from "react";
import { addStudent, getAllStudents, removeStudent } from "../API/StudentAPI";
import { AdminContext } from "../Router/AdminRouter";
import { useSnackbar } from "notistack";
import StudentForm from "../AdminComponent/StudentForm.js";
import TableHeader from "../Component/TableHeader";
import { FormModal } from "../AdminComponent/ModalAndAlert";
import { removeSemester } from "../API/AminAPI.js";

const StudentPage=()=>{
          const {setError}=useContext(AdminContext);
          const [studentData, setStudentData]=useState([]);
          const[show, setShow]=useState(0); //0: ko show, 1:show
          const [searchTerm, setSearchTerm]=useState("");
          const [search, setSearch]=useState("");
          const { enqueueSnackbar } = useSnackbar();
          const config = {variant: '',anchorOrigin:{ horizontal: 'center' , vertical: 'bottom'}}
          const studentDTO= {
                    id:0,
                    falcutyName: "",
                    program: "",
                    khoaTuyen: 0,
                    user: {
                        email: "",
                        userId: "",
                        name: "",
                        password:""
                    }
                }
          useEffect(()=>{
                    getAllStudents().then(res=>{
                              setStudentData(res.data)
                    })
                    .catch((err)=>setError(err))
          },[])
          const handleAddButton=(e)=>{
                    e.preventDefault();
                    setShow(1);
          }
          const handleSubmit=()=>{
                    addStudent(studentDTO).then(res=>{
                              setStudentData((prevStudentData)=>{
                                        const updatedSubjectData=[...prevStudentData];
                                        updatedSubjectData.push(res.data);
                                        return updatedSubjectData;
                              })
                              config.variant="success";
                              enqueueSnackbar("Thêm thành công sinh viên "+res.data.user.userId, config);
                              setShow(0);
                    })
                    .catch(err=>{
                            console.log("Err".err);
                              if(err.response.status==400){
                                        config.variant="error";
                                        enqueueSnackbar(err.response.data, config);
                              }
                              else setError(err)
                    })
          }
          const handleDelButton=(e,id)=>{
                    e.preventDefault();
                    removeSemester(id).then(res=>{
                              setStudentData((preStudentData)=>{
                                        return preStudentData.filter((data)=>data.id!=id)
                              })
                              config.variant="success";
                              enqueueSnackbar("Xóa thành công sinh viên ", config);
                    })
                    .catch(err=>setError(err))
          }
          const handleFilter = (item) => {
                    const re = new RegExp("^"+search,"i");
                    return item.user.userId.match(re);
          }
          const filterSubjects=(search==="")?studentData:studentData.filter(handleFilter);
          return(
                    <>
                    <div className="main-page">
                              <div className="ContentAlignment">
                                        <h1>Danh sách các sinh viên</h1>
                                        <button  type="button" className="btn btn-success" onClick={(e)=>handleAddButton(e)}>Add Student</button>
                                        <form className="d-flex col-lg-6" role="search" onSubmit={(e)=>{e.preventDefault(); setSearch(searchTerm);}}>
                                                  <input className="form-control me-2" type="search" placeholder="Tìm kiếm theo mã số sinh viên" id="Search" onChange={(e)=>setSearchTerm(e.target.value)}/>
                                                  <button className="btn btn-outline-success" type="submit" >Search</button>
                                        </form>
                              </div>
                              <div className="TableWapper border-bottom border-dark">
                                  <table className="table table-hover">
                                      <TableHeader data={["MSSV","Họ Tên","Khoa","Ngành","Khóa","Email","Action"]} />
                                      <tbody>
                                  {filterSubjects?.map((data)=> {
                                          return (
                                              <tr key={data.id}>
                                                  <th>{data.user.userId}</th>
                                                  <td>{data.user.name}</td>
                                                  <td>{data.falcutyName}</td>
                                                  <td>{data.program}</td>
                                                  <td>{data.khoaTuyen}</td>
                                                  <td>{data.user.email}</td>
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
                      {show==1&&<FormModal setShow={setShow} handleSubmit={handleSubmit} title="THÊM SINH VIÊN"><StudentForm studentDTO={studentDTO}/></FormModal>}
                    </>
          )
}
export default StudentPage;