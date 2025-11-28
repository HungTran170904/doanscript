import { useSnackbar } from "notistack";
import { useContext, useEffect, useState } from "react";
import { AdminContext } from "../Router/AdminRouter";
import { addSemester, getAllSemesters, removeSemester } from "../API/AminAPI";
import SemesterForm from "../AdminComponent/SemesterForm";
import TableHeader from "../Component/TableHeader";
import { FormModal } from "../AdminComponent/ModalAndAlert";

const SemesterPage=()=>{
          const {setError}=useContext(AdminContext);
          const [seData, setSeData]=useState([]);
          const[show, setShow]=useState(0); //0: ko show, 1:show
          const { enqueueSnackbar } = useSnackbar();
          const config = {variant: '',anchorOrigin:{ horizontal: 'center' , vertical: 'bottom'}}
          const semesterDTO={
                    semesterNum:0,
                    year:0
          }
          useEffect(()=>{
                    getAllSemesters().then(res=>{
                              setSeData(res.data)
                    })
                    .catch((err)=>setError(err))
          },[])
          const handleAddButton=(e)=>{
                    e.preventDefault();
                    setShow(1);
          }
          const handleSubmit=()=>{
                    console.log(semesterDTO)
                    addSemester(semesterDTO.semesterNum, semesterDTO.year).then(res=>{
                              setSeData((prevData)=>{
                                        const updatedData=[...prevData];
                                        updatedData.push(res.data);
                                        return updatedData;
                              })
                              config.variant="success";
                              enqueueSnackbar("Thêm thành công học kì  mới", config);
                              setShow(0);
                    })
                    .catch(err=>{
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
                              setSeData((preData)=>{
                                        return preData.filter((data)=>data.id!=id)
                              })
                              config.variant="success";
                              enqueueSnackbar("Xóa thành công học kì ", config);
                    })
                    .catch(err=>setError(err))
          }
          return(
          <>
                    <div className="main-page">
                              <div className="ContentAlignment">
                                        <h1>Danh sách các học kì</h1>
                                        <button  type="button" className="btn btn-success" onClick={(e)=>handleAddButton(e)}>Thêm kì mới</button>
                              </div>
                              <div className="TableWapper border-bottom border-dark">
                                  <table className="table table-hover">
                                      <TableHeader data={["STT","Học kì","Năm học","Action"]} />
                                      <tbody>
                                  {seData?.map((data, index)=> {
                                          return (
                                              <tr key={index}>
                                                  <th>{index+1}</th>
                                                  <td>Kì {data.semesterNum}</td>
                                                  <td>Năm học {data.year}-{data.year+1}</td>
                                                  <td colSpan={2}>
                                                            <button type="button" className="btn btn-danger mr-2" onClick={(e)=>handleDelButton(e,data.id)}>Delete</button>
                                                  </td>
                                              </tr>
                                          )
                                      })}
                                      </tbody>
                                  </table>
                              </div>
                    </div>
                      {show==1&&<FormModal setShow={setShow} handleSubmit={handleSubmit} title="THÊM HỌC KÌ"><SemesterForm semesterDTO={semesterDTO}/></FormModal>}
          </>
          )
}
export default SemesterPage;